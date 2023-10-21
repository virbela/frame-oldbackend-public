import { AvatarFacade } from "./../babylon/interfaces/Avatar";
import { Capability } from "@core/types/Capability";
import { IBaseModelUIOption, IBaseModelState } from "@core/types/BaseModel";
import { AssetData } from "@webapp/babylon/assets/Asset";
import { AudioData } from "@webapp/babylon/assets/Audio";
import { ModelData } from "@webapp/babylon/assets/Model";
import { NewsData } from "@webapp/babylon/assets/News";
import { ShapeData } from "@webapp/babylon/assets/Shape";
import { SpawnSpotData } from "@webapp/babylon/assets/SpawnSpot";
import { TextData } from "@webapp/babylon/assets/Text";
import { IZoneData } from "@webapp/babylon/assets/Zone";
import { Timestamp } from "firebase/firestore";
import { Slide, SlideSphereInfo } from "@core/sceneFunctions";
import { IFrame } from "@core/types/Frame";
import { Tier } from "@core/types/Tier";

import { StoreApi, StoreMutators } from "zustand/vanilla";
import { UserState } from "./types/UserState";
import { Ref } from "vue";
import { CameraMode, CameraRecenterMode } from "./CameraModeManager";
import { AbstractMesh } from "@babylonjs/core/Meshes";
import { BoundAsset } from "./types/AssetBinding";
import { ISupportRequestInfo } from "./types/Support";

/**
 * Replacement for Zustand StoreApi modified to include the new subscribe method
 * @param {object} T - the related state type, e.g. GlobalStateType
 */
export type SubscribeStoreApi<T> = StoreMutators<
  StoreApi<T>,
  unknown
>["zustand/subscribeWithSelector"];

// replace deprecated zustand utility types
export type StateSliceListener<T> = (slice: T, previousSlice: T) => void;
export type EqualityChecker<T> = (a: T, b: T) => boolean;
export type PartialState<T> = Partial<T> | ((s: T) => Partial<T>);

export type CombinedStateSelector<T, S, U> = (stateA: T, stateB: S) => U;

export type CombinedStateListener<T, S> = (stateA: T, stateB: S) => void;

export type CombinedStateSubscriber<AType, BType> = <StateSlice>(
  selector: CombinedStateSelector<AType, BType, StateSlice>,
  listener: StateSliceListener<StateSlice>,
  equalityFn?: EqualityChecker<StateSlice>
) => () => void;

/**
 * Combines two stores and return a `subscribe` method to subscribe to both stores at the same time.
 * @param storeA the first store
 * @param storeB the second store
 */
export function combineStores<AType, BType>(
  storeA: SubscribeStoreApi<AType>,
  storeB: SubscribeStoreApi<BType>
): { subscribe: CombinedStateSubscriber<AType, BType> } {
  const listeners: Set<CombinedStateListener<AType, BType>> = new Set();

  // notify listeners when storeA changes
  storeA.subscribe((stateA) => {
    listeners.forEach((listener) => listener(stateA, storeB.getState()));
  });

  // notify listeners when storeB changes
  storeB.subscribe((stateB) => {
    listeners.forEach((listener) => listener(storeA.getState(), stateB));
  });

  const defaultSelector = (stateA: AType, stateB: BType) => ({
    stateA,
    stateB,
  });

  const subscribe = <StateSlice>(
    selector: CombinedStateSelector<
      AType,
      BType,
      StateSlice
    > = defaultSelector as any,
    listener: StateSliceListener<StateSlice>,
    equalityFn: EqualityChecker<StateSlice> = Object.is
  ): (() => void) => {
    // the current state slice (use current getState)
    let currentSlice: StateSlice = selector(
      storeA.getState(),
      storeB.getState()
    );
    // this function gets called on state changes
    async function listenerToAdd() {
      // delay execution of state handlers until next event loop to avoid race conditions
      await Promise.resolve();
      // get the current state slice which will be the next state slice
      const nextSlice = selector(storeA.getState(), storeB.getState());
      // only run callback when slices are not equal
      if (!equalityFn(currentSlice, nextSlice)) {
        const previousSlice = currentSlice;
        listener((currentSlice = nextSlice), previousSlice);
      }
    }
    listeners.add(listenerToAdd);
    // Unsubscribe
    return () => listeners.delete(listenerToAdd);
  };

  return {
    subscribe,
  };
}

/**
 * Utility to wait for a state property to become true before proceeding.
 * Guaranteed to resolve whether property is already true or becomes true later.
 * @param  {SubscribeStoreApi<T>} state stateManager to watch
 * @param  {string|(state: T) => boolean} selection Either a property name string, or, for compound states, a state selector function
 * @returns Promise Resolves to true when the property becomes true
 */

export function waitForState<T>(
  state: SubscribeStoreApi<T>,
  selection: (keyof T & string) | ((state: T) => boolean)
): Promise<true> {
  const selector: (state: T) => boolean =
    typeof selection === "string" ? (state) => !!state[selection] : selection;
  return new Promise((resolve) => {
    if (selector(state.getState())) {
      return resolve(true);
    }
    const unsub = state.subscribe(selector, (ready) => {
      if (ready) {
        unsub();
        resolve(true);
      }
    });
  });
}

export type LinkTypeChoice = "webLink" | "frameLink" | "spotLink";
export interface Destination {
  /** database id, doesn't exist on new object */
  id?: string;
  name: string;
  linkType: LinkTypeChoice;
  value: string;
  /** undefined means global */
  parentCategory?: string;
  category?: string;
  order?: number;
  description?: string;
  thumbnailInfo?: {
    url: string;
    public_id?: string;
  };
  /** ui only */
  participantCount?: number;
}
export enum ZoneLockState {
  FORBIDDEN = "forbidden",
  UNAVAILABLE = "unavailable",
  LOCKABLE = "lockable",
  UNLOCKABLE = "unlockable",
}

export interface StateNotificationType {
  duration?: number;
  title?: string;
  text: string;
  data?: any;
  actionable?: boolean;
  dismissable?: boolean;
  icon?: any;
}

export interface GlobalStateType extends AppSettings {
  apiURL: string;
  signalingURL: string;
  /** If virbela.com or framevr.io emails */
  isDeveloper: boolean;
  /**
   * is the ?debug=true url param set (enables babylon inspector)
   */
  isDebugMode: boolean;
  domContentLoaded: boolean;
  shouldLoadBabylon: boolean;
  hardwareGranted: {
    microphone: boolean;
    camera: boolean;
    desktop: boolean;
  };
  isChatSupportActive: boolean;
  nextTutorialStep: () => void;
  previousTutorialStep: () => void;
  deactivateTutorial: () => void;
  activateTutorial: () => void;
  setCloneOptions: (cloneOptions: {
    copyMembers?: boolean;
    copyAdmins?: boolean;
  }) => void;
  audioPlayback: boolean;
  disregardFPS: boolean;
  textAreaBeingEdited: string;
  /** Nametags visible or not */
  nametagsEnabled: boolean;
  hardwareEnabled: {
    microphone: boolean;
    camera: boolean;
    desktop: boolean;
  };
  facade: AvatarFacade;
  restrictAllAssetsToZones: () => boolean;
  micBlockedFromFrame: () => boolean;
  camBlockedFromFrame: () => boolean;
  disabledFeatures: any;
  activeSlideId: string;
  sphereExpanded: boolean;
  /** what kind of sphere is currently expanded: photo, video, or shader */
  sphereType: string;
  backgroundAssets: boolean;
  editObjectId: string | null;
  editModeEnabled: boolean;
  /**
   * Controls whether the initial frame spinner loading screen is showing
   */
  loadingScreen: boolean;
  frameBound: boolean;
  userBound: boolean;
  appSettingsBound: boolean;
  babylonSceneLoaded: boolean;
  /** The initial environment model has finished loading */
  baseModelLoaded: boolean;
  baseModel: IBaseModelState;
  environmentNMEnabled: boolean;
  /**
   * Whether current user is currently participating in the frame. Change to false triggers a disconnect
   */
  isConnected: boolean;
  /**
   * Is the backend ready for user to connect to the frame?
   * note: Typically set active by the avatar_harness setting this state value to true
   *       when responding to the avatar callbacks
   */
  isWebRTCReady: boolean;
  hasEverConnected: boolean;
  isSinglePlayerMode: boolean | null;
  /// Permissions ///
  /**
   * User's permission role in this frame.
   * TODO: this is defined in permissions.js, can update this to import the type once that is ported to TS
   */
  userRole: "guest" | "member" | "admin" | "owner";

  /** Represents the networking PeerID */
  peerId?: string;

  /** Make persistent changes to frame content. e.g. create / move / update assets */
  editPermission: boolean;
  /** Make transient changes to frame content. e.g. change pdf page, open videosphere */
  interactPermission: boolean;
  /** subset of interactPermission specific to photosphere asset */
  photospherePermission: boolean;
  /** subset of interactPermission specific to emoji emission */
  emojiPermission: boolean;
  /** subset of interactPermission specific to locking zones */
  zoneLockPermission: false;
  /**
   * subset of interactPermission specific to streaming screens.
   * Do not use this directly in feature logic.
   * Use streamScreensDisabled computed value instead
   */
  streamingPermission: boolean;
  /** Connect to the frame. */
  viewPermission: boolean;
  /** Activate your mic and transmit voice to other users */
  micPermission: boolean;
  /** Activate your webcam and transmit video to other users (both avatar cam and streaming screen) */
  cameraPermission: boolean;
  /** Create events and invite people to this frame */
  calendarInvitePermission: boolean;
  /** Edit this frame's Go To menu */
  destinationsEditPermission: boolean;
  /** Edit this server's global Go To menu */
  globalDestinationsEditPermission: boolean;
  /** View lists of all frames on this server with user counts */
  activeFramesViewPermission: boolean;
  /** Change this frame's settings, manage online users */
  frameAdminPermission: boolean;
  /** Delete frame, change what other admins can do */
  frameOwnerPermission: boolean;
  /** is the user forbidden from streaming to streaming screens? */
  streamScreensDisabled: () => boolean;
  backgroundPhotosphere: boolean;
  avatar: PeerStateAvatarType;
  frame: IFrame;
  capabilities: { [key: string]: Capability } | undefined;
  closedCaptionsUserCount: number;
  voiceInputLang: string;
  emojisOpen: boolean;
  allowSpeechRecognition: boolean | null;
  /** Name of current voice zone (different from avatar.voiceZone which is unique id) */
  currentZoneName: string | null;
  /** Base voice zones for quick, unknown purpose */
  baseVoiceZones: { id: string | null; name: string }[]; // incompletely known type or purpose
  /** Is the current zone locked or is it lockable by this user */
  currentZoneLockState: ZoneLockState;
  addNotification: (notif: StateNotificationType) => void;
  isGlobalAdmin: boolean;
  disableLocationSharing: boolean;
  appSettingsID: string;
  /// data ///
  globalDestinations: Destination[];
  destinations: Destination[];
  textChatLang: string;
  chatsUnreadCount: number;
  userID: string;
  email: string;
  /** lookControlsDisabled: whether or not look controls are disabled */
  lookControlsDisabled: boolean;
  /** arrowKeysTurnUser - whether or not arrow keys turn the user, default to true for logged-out users */
  arrowKeysTurnUser: boolean;
  /** avatarOptimizationOverrideEnabled: whether the avatar silhouette/indicator optimizations should be overridden, always displaying full avatars */
  avatarOptimizationOverrideEnabled: boolean;
  /** clickToMove: whether or not click to move is enabled */
  clickToMove: boolean;
  /** user preference to always use lotus seating pose even when chair pose is available */
  prefersLotus: boolean;
  /** thirdPersonCameraEnabled: Whether the user has ENABLED ThirdPersonCamera (may not be active) */
  thirdPersonCameraEnabled: () => boolean;

  /**
   * thirdPersonCameraActive:
   * Whether the ThirdPersonCamera is currently active (not to be confused with enabled)
   * ThirdPersonCamera will be forced inactive under specific state conditions
   */
  thirdPersonCameraActive: () => boolean;
  isRecording: boolean;
  isExternalInterface: boolean;
  mainlineDomain: string;
  maxFrames: number;
  userLoggedIn: boolean;
  slides: Slide[];
  activeSlide: Slide & SlideSphereInfo;
  claimedSpace: boolean;
  camPlacement: boolean;
  isMobile: boolean;
  /** isIpad: whether or not the user is on an ipad */
  isIpad: boolean;
  /** currently running in a safari browser as detected by UA string */
  isSafari: boolean;
  /** isSafari && isMobile (i.e. safari on iPhone or iPad) */
  isMobileSafari: boolean;
  /** currently running in Oculus Browser as detected by UA string */
  isMobileVR: boolean;
  /** currently running chrome on iOS as detected by UA string */
  isIOSChrome: boolean;
  skyBoxGenerationStatus: string;
  api: { key: string | null; timestamp: Timestamp | null };
  tutorialStep: number;
  isSpectator: boolean;
  /// Connections ///
  connectionsServiceAvailable: boolean;
  showConnectionsActivation: boolean;
  /** User profile setting to decline connections activation prompts */
  doNotShowConnectionsActivation: boolean;
  /**
   * Was the current connections activation modal opened by the system (true)
   * or by the user (false)
   */
  connectionsActivationAutoPopup: boolean;
  /** Unique username for connections */
  connectionsUsername: string | undefined;

  draggingModelFromSidebar: boolean;

  snapModeEnabled: boolean;

  /**
   * Whether `avatarFullBodyLocked` has been enabled in `appSettings. This is used to determine
   * whether users should be able to toggle between Legacy (Floater) or Full-Body avatars.
   * There is also a frame-level prop of the same name used to determine this.
   */
  avatarFullBodyLocked: boolean;

  /**
   * Whether `disallowGuests` has been enabled in `appSettings` which disallows logged-out users.
   * Note that there is also a frame-level `disallowGuests` that takes precedence if more restrictive.
   */
  disallowGuests: boolean;
  frameUpgradeDialogData: {
    /**
     * frameUpgradeDialog
     * true = upgrade dialog visible
     * false = upgrade dialog hidden
     */
    frameUpgradeDialog?: boolean;
    frameToUpgrade?: IFrame;
    remix?: boolean;
    clone?: boolean;
    upgrade?: boolean;
    isAdminDialog?: boolean;
    cloneOptions?: { copyMembers?: boolean; copyAdmins?: boolean };
    selectedTierId?: number;
  };
  /**
   * user's unique id on the media server
   */
  avatarId: string | undefined;
  /**
   * directCheckoutData (used for referral program and direct checkout links)
   */
  directCheckoutData: {
    /**
     * shows direct checkout dialog
     */
    directCheckout: boolean;
    frameToPurchase: {
      name?: string;
      baseModel?: IBaseModelUIOption;
    };
    selectedTierId: number;
  };
  sidebarTakeover: boolean;
  sidebarTakeoverComponentPath: string | undefined;
  /**
   * sets sidebar takeover component, and opens sidebar
   */
  sidebarTakeoverMode: (componentPath: string) => void;
  closeSidebarTakeover: () => void;
  showDirectCheckout: () => void;
  hideDirectCheckout: () => void;
  toggleSidebar: () => void;
  hideSidebar: () => void;
  closeSidebar: () => void;
  /** show the Vue sidebar menu */
  openSidebar: () => void;
  /** expand a panel of spaces (Frames) in the sidebar just once */
  showSpacesPanelOnce: number;
  setDirectCheckoutFrameData: (newFrameData: {
    name?: string;
    baseModel?: IBaseModelUIOption;
    frameToPurchase?: {
      name?: string;
      baseModel?: IBaseModelUIOption;
    };
  }) => void;
  setDirectCheckoutTierId: (newId: number) => void;
  /**
   * Current user has haccess to /home?
   * Controlled by appSettings.portalDomains.
   * If portaldDomains unset or empty list, returns true
   */
  hasHomeAccess: () => boolean;

  isStaff: () => boolean;

  interactivityDialog: { show: boolean; assetId?: string };
  showInteractivityDialog: (assetId?: string) => void;
  hideInteractivityDialog: () => void;
  showUpgradeDialog: (params: {
    frame?: IFrame;
    selectedTierId?: number;
    remix?: boolean;
    clone?: boolean;
    upgrade?: boolean;
    isAdminDialog?: boolean;
  }) => void;
  hideUpgradeDialog: () => void;
  /**
   * Set to `true` once `scene.onReadyObservable` fires (initial only)
   * Not to be confused with `babylonSceneLoaded` which is fired before the scene is ready
   */
  isBabylonSceneReady: boolean;
  /** Computed state for when the QuickUI should be created/displayed */
  shouldDisplayQuickUI: () => boolean;
  /** Enables the vue avatar builder */
  showAvatarBuilder: () => void;
  /** Disables the vue avatar builder */
  hideAvatarBuilder: () => void;
  /**
   * Toggles the Vue Avatar Customization UI (new)
   * This is used in state; use `toggleAvatarCustomization` in client code
   */
  toggleAvatarBuilder: () => void;
  /**
   * Toggles the Babylon Avatar Customization UI (legacy)
   * This is used in state; use `toggleAvatarCustomization` in client code
   */
  toggleAvatarBuilderLegacy: () => void;
  /** Toggles appropriate Avatar Customization based on conditions */
  toggleAvatarCustomization: () => void;
  /** Whether vue avatar builder toggle has been enabled */
  avatarBuilder: boolean;
  /** Whether the Vue Avatar Builder should be displayed */
  shouldDisplayAvatarBuilder: () => boolean;
  /** Whether the Babylon Avatar UI (legacy) is active */
  isAvatarBuilderLegacyActive: () => boolean;
  /** Whether conditions are met to allow obstructive Babylon UI to be displayed */
  canDisplayObstructiveBabylonUI: () => boolean;
  /** Whether the Password protection UI should be displayed */
  shouldDisplayPasswordUI: () => boolean;
  /** Checks whether the Connect UI should be displayed (not including password input) */

  shouldDisplayConnectUI: () => boolean;
  isCurrentFrameOwned: () => boolean;
  isPasswordSatisfied: () => boolean;
  isPeerCountWithinLimit: () => boolean;
  isSpectatorCountWithinLimit: () => boolean;
  isReadyForConnectUI: () => boolean;
  canConnectAsUser: () => boolean;
  canConnectAsSpectator: () => boolean;
  canConnectAsSinglePlayer: () => boolean;
  setSelectedTierId: ({ selectedTierId }: { selectedTierId: number }) => void;
  /**
   * Whether the Full Body Avatars toggle should be disabled. This checks both app-level
   * and frame-level versions of `avatarFullBodyLocked`.
   */
  disableAvatarBodyToggle: () => boolean;

  // the following items were reconciled from state.js during zustand 4 conversion
  /**
   * whether certain UI/features are active/visible
   */
  isAssetOptionsBarVisible: boolean;
  /**
   * isConfirmDialogVisible: whether the ConfirmationQueue dialog is visible
   */
  isConfirmDialogVisible: boolean;
  /**
   * Controls hiding/showing babylon UI
   */
  mainUIActive: boolean;
  /** Controls which panel is showing in the babylon UI. default: "GENERAL" */
  mainUIPanel: string;
  /**
   * whether or not the user is zoomed in with ZoomBehavior
   */
  isUserZoomedIn: boolean;
  /**
   * Avatar camera mode (first, third-person, etc.)
   */
  cameraMode: CameraMode;
  /**
   * cameraRecenterMode: Avatar camera auto-recenter mode.
   */
  cameraRecenterMode: CameraRecenterMode;
  /**
   * isCameraAttachedUIVisible: whether or not the camera attached UI is visible
   */
  isCameraAttachedUIVisible: () => boolean;
  /**
   * whether currently in an immersive WebXR session. Set to false to force exit VR.
   */
  vrEnabled: boolean;
  /**
   * Whether the right hand VR controller model has loaded
   */
  rightVRControllerLoaded: boolean;
  /**
   * Whether the left hand VR controller model has loaded
   */
  leftVRControllerLoaded: boolean;
  /**
   * Whether the right hand VR hand tracking model has loaded
   */
  leftVRHandLoaded: boolean;
  /**
   * Whether the left hand VR hand tracking model has loaded
   */
  rightVRHandLoaded: boolean;
  /**
   * leftHandVRUI: whether or not the left hand VR UI is enabled
   */
  leftHandVRUI: boolean;
  /**
   * User preference to enable moving joystick locomotion
   */
  vrJoystickLocomotion: boolean;
  /**
   * User preference to enable WebXR hand tracking input (experimental)
   */
  handTrackingEnabled: boolean;
  /**
   * User preference to enable the use of interactive maps in place of base models (experimental)
   */
  mapEnvironments: boolean;
  /**
   * whether the user is currently sitting
   */
  sitting: boolean;
  /** has the correct password been entered in the connect UI */
  passwordSet: boolean;
  /**
   * the number of avatars in the frame
   */
  participantCount: number;
  /**
   * the total number of people known to the backend.
   * Equivalent to {@link participantCount} + {@link spectatorCount} + {@link lobbyCount}.
   * You probably want one of those counts instead of this one.
   */
  peerCount: number;
  /**
   * the number of people still at the connect screen
   */
  lobbyCount: number;
  /**
   * the number of people spectating without an avatar
   */
  spectatorCount: number;
  /**
   * whether a transition is currently in progress
   */
  quickTraverse: boolean;
  /**
   * should the user proceed past the connect screen automatically when able? (enabled during transitions or by ?connect=true)
   */
  isAutoConnectMode: boolean;
  /**
   * whether or not the user is using chrome browser
   */
  isChrome: boolean;
  /**
   * is this device capable of an "immersive-vr" WebXR session. Note: all android/chrome will report true for this even if all they support is cardboard mode regardless of whether the user actually possesses a cardboard viewer
   */
  vrImmersable: boolean;
  /**
   * portalDomains: used by portal only. array of who's allowed to access. (data type?)
   */
  portalDomains: string[];
  /**
   * which email domains are considered Frame staff users (grants unlimited frames)
   */
  staffDomains: string[];
  /**
   * pendingNotifications: array of the pending notifications (data type?)
   */
  pendingNotifications: StateNotificationType[];
  /**
   * isSidebarOpen: whether or not the sidebar is open
   */
  isSidebarOpen: boolean;
  setTutorialStep: (step: number) => void;
  /**
   * tutorialActive: (legacy) whether or not the tutorial is active
   */
  tutorialActive: boolean;

  /**
   * Babylon node name for active (i.e. rendering) camera. See PlayerCamera
   */
  activeCameraName: string;

  /**
   * whether the user is currently flying
   */
  flyModeOn: boolean;

  /**
   * iso string of when the user profile was created
   */
  userCreatedTimestamp: Timestamp | undefined;
  /**
   * holds cache of babylon NodeMaterials from materialHelpers.js.
   * TODO: consider migrating out of state since it is not storing simple, serializable data,
   * and because none of the use cases for this appear to use any reactivity
   */
  nodeMaterials: Map<string, any>;
  /**
   * When populated, only the listed meshes are interactive. Used for creating blocking popup menus in babylon.
   */
  pickableMeshes: null | AbstractMesh[];
  /**
   * assets currently marked for exclusive control by local user (streaming screens, zones)
   */
  boundAssets: BoundAsset[];
  /**
   * browser-provided id of the webcam device selected by the user
   */
  selectedVideoDevice: string | boolean;
  /**
   * browser-provided id of the microphone device selected by the user
   */
  selectedAudioDevice: string | boolean;
  /** Is the babylon text renderer ready to use */
  mtsdfTextReady: boolean;
}

export interface PeerStateAvatarType {
  id: string;
  lobby: boolean;
  spectate: boolean;
  audioMuted: boolean;
  closedCaptionsEnabled: boolean;
  voiceZone: null | string;
  videoPanelEnabled: boolean;
  desktopVideoPanelEnabled: boolean;
  megaphoneEnabled: boolean;
  janusID: string;
  photo: string | undefined;
  isTyping: boolean;
  isPointing: boolean;
  sitting: boolean;
  animations: string[];
  pointerHand: string;
  immersProfileURL: string | undefined;
  immersId: string | undefined;
  immersHandle?: string;
  handsEnabled: boolean;
  email?: string;
  isGuest: boolean;
  prefersLotus: boolean;

  nametag: string;
  statusMessage: string | undefined;
  linkedInURL: string | undefined;
  twitterURL: string | undefined;
  company: string;
  isActive: boolean;
  supportRequestInfo: ISupportRequestInfo | undefined;
  systemInfo: any;
  pollResponse?: { color: string; text: string };
  isFlat?: boolean;
  seatId: string;
  isAdmin: boolean;
  discEnabled: boolean;
}

/** Typescript definition for AppSettings collection */
export interface AppSettings {
  alwaysSupportWidget: boolean;
  cacheRelease: {
    [key: string]: Timestamp;
    "all-cache": Timestamp;
  };
  creatorDomains: string[];
  dateAdded: Timestamp;
  defaultBrowserURL: string;

  globalDestinationCategories: string[];
  staffDestinationCategories: string[];
  homeFrame: string | undefined;
  homeRedirect: string | undefined;
  portalDomains: string[];
  showAllFramesInPortal?: boolean;

  loginMethods: {
    email: boolean;
    google: boolean;
    microsoft: boolean;
    facebook: boolean;
    immers: boolean;
    /** other OIDC providers configured via immers server */
    custom: boolean;
  };
  subscriptionsEnabled: boolean;
  announcement: string | undefined;
  staffAnnouncement: string | undefined;

  tiers: { dev: Tier[]; production: Tier[] };

  autoExpandedGotoMenu: boolean;
  staffDomains: string[];

  defaultFrameSettings?: Partial<IFrame>;
  /** enable showing user system information to admins in people menu */
  collectPeerSystemInfo?: boolean;

  /** unused */
  subBrandable: boolean;
  /** unused */
  enableConnections: boolean;
}

// appsettings is mixed into state directly

export interface AssetStateType {
  assets: Array<AssetData>;
  loadedAssetTypes: string[];
  flatStreamingScreens: boolean;
  addItem: (item: AssetData) => void;
  deleteItem: (id: string) => void;
  getItemById: (id: string) => AssetData | undefined;
  deleteAllItems: () => void;
  updateItem: (updatedItem: AssetData) => void;

  setTypeAsLoaded: (type: string) => void;
  // TODO this probably should all be AssetData, because thats the
  // only data structure interface added (comes from arbitrary firebase
  // json ultimately), but the intention is to only return that specific
  // type of data from these methods.
  models: () => Array<ModelData>;
  shapes: () => Array<ShapeData>;
  audios: () => Array<AudioData>;
  pdfs: () => Array<AssetData>;
  images: () => Array<AssetData>;
  spheres: () => Array<AssetData>;
  videospheres: () => Array<AssetData>;
  videos: () => Array<AssetData>;
  spawnSpots: () => Array<SpawnSpotData>;
  texts: () => Array<TextData>;
  particles: () => Array<AssetData>;
  voiceZones: () => Array<IZoneData>;
  polls: () => Array<AssetData>;
  news: () => Array<NewsData>;
  shaders: () => Array<AssetData>;
  textareas: () => Array<AssetData>;
  geoTexts: () => Array<AssetData>;
  stocktickers: () => Array<AssetData>;
  npcs: () => Array<AssetData>;
  whiteboards: () => Array<AssetData>;
  basemodelChairs: () => Array<AssetData>;
  remotebrowsers: () => Array<AssetData>;
  webScreenshots: () => Array<AssetData>;
  videoStorageUsed: number;
  streamingScreens: () => Array<AssetData>;
  updateVideoStorageUsed: () => void;
}

// TBD - more refined definition. Doesnt appear to be exactly the same as AssetData
export type InventoryAssetData = {
  docId?: string;
} & Record<string, any>;

export interface InventoryStateType {
  inventoryItems: Array<InventoryAssetData>;
  videoStorageUsed: number;
  addItem: (item: InventoryAssetData) => void;
  deleteItem: (id: string) => void;
  updateItem: (updatedItem: InventoryAssetData) => void;
  inventoryModels: () => Array<InventoryAssetData>;
  inventoryAudios: () => Array<InventoryAssetData>;
  inventoryPdfs: () => Array<InventoryAssetData>;
  inventoryImages: () => Array<InventoryAssetData>;
  inventoryPhotospheres: () => Array<InventoryAssetData>;
  inventoryVideospheres: () => Array<InventoryAssetData>;
  inventoryVideos: () => Array<InventoryAssetData>;
  updateVideoStorageUsed: () => void;
}

type ChatsCommon = {
  id: string;
  messageBody: string;
  sender: string;
  timeStamp: Timestamp;
  voiceInputLang: string;
  htmlLink?: boolean;
};

export type PrivateChatsDoc = ChatsCommon & {
  participants?: string[];
  readBy: string[];
  senderID?: string;
};

export type ChatDataType = ChatsCommon & {
  originalMessage?: string;

  // For Main/Zoned Chats
  senderPeerId: string;
  senderVoiceZone?: string | null;
  senderIsInMyZone?: boolean;
  fromSpeech?: boolean;

  // For Private Chats
  participants?: string[];
  senderID?: string;
  isPrivateChat?: boolean;
  readBy?: string[];
};

export type ChatOptions = {
  htmlLink: boolean;
  objectPath?: string;
  chatId?: string;
};

export type UploadFileOptions = {
  vueFileUploadingRef: Ref<boolean>;
  fileInfo: Ref<SharedFileInfo | null>;
  frameName?: string;
  chatId: string;
};

export type SharedFileInfo = {
  folderId: string;
  fileName: string;
  downloadUrl: string;
  frameName?: string;
  chatId: string;
};

export type ChatGroup = {
  chats: ChatDataType[];
  nametags: string;
  unreadCount: number;
};

export type ChatGroups = { [key: string]: ChatGroup };

export interface ChatStateType {
  chats: ChatDataType[];
  chatGroups: { [key: string]: any };
  addChat: (chat: ChatDataType) => void;
  deleteChat: (id: string) => void;
  getChatById: (id: string) => void;
  deleteAllChats: () => void;
  deleteAllPrivateChats: () => void;
  updateChat: (updatedChat: ChatDataType) => void;
}

export type AssetStateStoreType = SubscribeStoreApi<AssetStateType>;
export type ChatStateStoreType = SubscribeStoreApi<ChatStateType>;
export type GlobalStateStoreType = SubscribeStoreApi<GlobalStateType>;
export type UserStoreStateType = SubscribeStoreApi<UserState>;
export type InventoryStoreStateType = SubscribeStoreApi<InventoryStateType>;

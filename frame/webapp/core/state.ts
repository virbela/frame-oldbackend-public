/*                  *
 * State management *
 *  by zustand      */

import { createStore } from "zustand/vanilla";
import { subscribeWithSelector } from "zustand/middleware";
import { getUrlParameter } from "./utils/url";
import { getApiUrl, getSignalingUrl } from "./backend";
import branding from "./branding";
import { CameraMode, CameraRecenterMode } from "@core/CameraModeManager";
import { getMainlineDomain } from "@core/utils/joinFunctions";
import { frameCapabilityValue, frameCreate } from "@core/utils/Frame";
import { GlobalStateType, ZoneLockState } from "./state-utils";
import { Timestamp } from "firebase/firestore";
import { baseModelStateHydrate } from "./utils/BaseModel";

const stateManager = createStore<GlobalStateType>()(
  subscribeWithSelector((set, get) => ({
    /**
     * apiURL - the base URL for all API calls
     */
    apiURL: getApiUrl(),

    /**
     * signalingURL - the base URL for all signaling calls
     */
    signalingURL: getSignalingUrl(),

    /**
     * disabledFeatures - list of disabled features
     */
    disabledFeatures: [],
    loadingScreen: true,

    /**
     * activeSlideId - the active slide id
     */
    activeSlideId: "",

    /**
     * activeSlide - the active slide
     */
    activeSlide: {
      currentPhotosphere: "none",
      currentVideoSphereHLSURL: "",
      currentVideoSphereMPDURL: "",
      assetID: "",
      id: "",
      order: 0,
    },

    /**
     * destinations - destination objects set by dbDestinations (data type?)
     */
    destinations: [],

    /**
     * globalDestinations - global destination objects (data type)
     */
    globalDestinations: [],

    /**
     * slides - slide objects set by dbScenes (data type?)
     */
    slides: [],

    /**
     * backgroundAssets - whether or not background assets are enabled
     */
    backgroundAssets: false,

    /**
     * backgroundPhotosphere - whether or not background photosphere is enabled
     */
    backgroundPhotosphere: false,

    /**
     * baseModelLoaded: both base model & navigation mesh have been loaded. navigation features are not safe to use until this is true
     */
    baseModelLoaded: false,

    /**
     * which device was selected for microphone
     */
    selectedAudioDevice: true,

    /**
     * video device selected for the user
     */
    selectedVideoDevice: false,

    /**
     * baseModel - the base model for the current frame
     */
    baseModel: baseModelStateHydrate(),

    /**
     * sphereExpanded: whether or not a 360 photosphere is expanded in the current frame
     */
    sphereExpanded: false,

    /**
     * Environment tile
     */
    environmentNMEnabled: false,
    /**
     * chatsUnreadCount: number of unread chats
     */
    chatsUnreadCount: 0,

    /**
     * editModeEnabled: whether or not edit mode is enabled
     */
    editModeEnabled: false,

    /**
     * flyModeOn: whether or not fly mode is enabled
     */
    flyModeOn: false,

    /**
     * sitting: whether or not the user is currently sitting
     */
    sitting: false,

    /**
     * disregardFPS: whether or not to disregard FPS
     */
    disregardFPS: true,

    /**
     * vrJoystickLocomotion: whether vr joystick locomotion is enabled
     */
    vrJoystickLocomotion: false,

    /**
     * basketBallStarted - whether or not the basketball game has started
     */
    basketballStarted: false,

    /**
     * maxFrames: the maximum number of trial frames users can claim (non isDeveloper users)
     */
    maxFrames: 3,

    /**
     * quickTraverse: whether or not quick traverse is enabled
     */
    quickTraverse: false,

    /**
     * email: the user's email
     */
    email: "",

    /**
     * emailVerified: whether or not the user's email is verified
     */
    emailVerified: false,

    /** Whether vue avatar builder toggle has been enabled */
    avatarBuilder: false,

    /**
     * frame: the currently loaded Frame
     */
    frame: frameCreate(),

    /**
     * spectatorCount: the number of spectators
     */
    spectatorCount: 0,

    /**
     * participantCount: the number of participants
     */
    participantCount: 0,

    /**
     * lobbyCount: the number of users in the lobby
     */
    lobbyCount: 0,

    /**
     * peerCount: the number of peers
     */
    peerCount: 0,

    /**
     * Networked PeerID
     */
    peerId: "",

    /**
     * frameBound: whether initial frame state has been set from DB
     */
    frameBound: false,

    /**
     * homeFrame: the home frame
     */
    homeFrame: branding.homeFrame,

    /**
     * homeRedirect: the home redirect
     */
    homeRedirect: branding.homeRedirect,

    /**
     * userID string representation of the current userID
     */
    userID: "",

    /**
     * userLoggedIn: whether or not the user is logged in
     */
    userLoggedIn: false,

    /**
     * userCreatedTimestamp: timestamp of when the user was created. datatype?
     */
    userCreatedTimestamp: undefined,

    /**
     * userBound: whether initial auth state has occured, whether logged in or not
     */
    userBound: false,

    /**
     * isDeveloper: whether or not the user is a developer (an @virbela.com or an @framevr.io email)
     */
    isDeveloper: false,

    /**
     * isSidebarOpen: whether or not the sidebar is open
     */
    isSidebarOpen: false,

    /**
     * textChatIsActive: whether or not text chat is active
     */
    textChatIsActive: false,

    /**
     * textChatLang: string representing the text chat language. possible values?
     */
    textChatLang: "none",

    /**
     * textChatUnreadCount: count of unread chats
     */
    textChatUnreadCount: 0,

    /**
     * audio - state of audio effects
     */
    audio: {
      spacialization: true,
    },

    /**
     * videoDevices: array of video devices. data type?
     */
    videoDevices: [],

    /**
     * audioDevices - list of available audio devices
     */
    audioDevices: [],

    /**
     * isMobileDeviceRequestingDesktopSite: whether or not the mobile device is requesting the desktop site
     */
    isMobileDeviceRequestingDesktopSite: false,

    /**
     * isMobile: whether or not the user is on a mobile device
     */
    isMobile: false,

    /**
     * isMobileVR: whether or not the user is on a mobile device and in VR mode
     */
    isMobileVR: false,

    /**
     * isSafari: whether or not the user is on safari browser
     */
    isSafari: false,

    /**
     * isIpad: whether or not the user is on an ipad
     */
    isIpad: false,

    /**
     * isMobileSafari: whether or not the user is using safari on mobile
     */
    isMobileSafari: false,

    /**
     * isIOSChrome: whether the user is using chrome on ios
     */
    isIOSChrome: false,

    /**
     * isHeadsetConnected: whether the user's headset is connected
     */
    isHeadsetConnected: false,

    /**
     * isUserZoomedIn: whether or not the user is zoomed in
     * (on what?)
     */
    isUserZoomedIn: false,

    /**
     * isDebugMode: whether or not debug mode is enabled
     */
    isDebugMode: getUrlParameter("debug") === "true",

    /**
     * isAutoConnectMode: whether or not auto connect mode is enabled
     */
    isAutoConnectMode: getUrlParameter("connect") === "true",

    /**
     * joystickOverrideEnabled: whether or not the joystick override is enabled
     */
    joystickOverrideEnabled: false,

    /**
     * lookStickOverrideEnabled: whether or not the look stick override is enabled
     */
    lookStickOverrideEnabled: false,

    /**
     * gyroOverrideEnabled: whether or not to override the gyro
     */
    gyroOverrideEnabled: false,

    /**
     * isVRMode: **DEPRECATED** do not use. always false
     */
    isVRMode: false,

    /**
     * rightVRControllerLoaded: whether or not the right VR controller is loaded
     */
    rightVRControllerLoaded: false,

    /**
     * leftVRControllerLoaded: whether or not the left VR controller is loaded
     */
    leftVRControllerLoaded: false,

    /**
     * leftVRHandLoaded: whether or not the left VR hand is loaded
     */
    leftVRHandLoaded: false,

    /**
     * rightVRHandLoaded: whether or not the right VR hand is loaded
     */
    rightVRHandLoaded: false,

    /**
     * controllerConnected: whether or not the controller is connected
     */
    controllerConnected: false,

    /**
     * wristUIEnabled: whether or not the wrist ui is enabled
     */
    wristUIEnabled: true,

    /**
     * leftHandVRUI: whether or not the left hand VR UI is enabled
     */
    leftHandVRUI: true,

    /**
     * shouldLoadBabylon: whether or not to load babylon
     */
    shouldLoadBabylon: false,

    /**
     * babylonSceneLoaded - true as soon as the babylon scene object has been initialized. Models and assets may still be loading.
     * @see baseModelLoaded for detecting when environment is ready
     */
    babylonSceneLoaded: false,
    /**
     * mainUIPanel: string representing the currently active tab in the "mainUiPanel". default: "GENERAL"
     */
    mainUIPanel: "GENERAL",

    /**
     * mainUIActive: whether or not the main UI is active
     */
    mainUIActive: false,

    /**
     * editPermission: whether or not the user has edit permission (to make persistent changes to frame content. e.g. create / move / update assets)
     */
    editPermission: false,

    /**
     * interactiPermission: whether user can Make transient changes to frame content. e.g. change pdf page, open videosphere
     */
    interactPermission: false,

    /**
     * photospherePermission: ? subset of interactPermission specific to photosphere asset
     */
    photospherePermission: false,

    /**
     * emojiPermission: subset of interactPermission specific to emoji emission
     */
    emojiPermission: false,

    /**
     * zoneLockPermission: subset of interactPermission specific to locking zones
     */
    zoneLockPermission: false,

    /**
     * streamingPermission: whether or not streaming is enabled
     */
    streamingPermission: false,

    /**
     * viewPermission: ?
     */
    viewPermission: false,

    /**
     * micPermission: true to Activate user's mic and transmit voice to other users
     */
    micPermission: false,

    /**
     * cameraPermission: whether the user has permission to share their webcam in this frame (both avatar cam and streaming screen)
     */
    cameraPermission: false,

    /**
     * calendarInvitePermission - whether there is permission to Create events and invite people to this frame
     */
    calendarInvitePermission: false,

    /**
     * destinationsEditPermission:  whether the user can edit this frame's Go To menu
     */
    destinationsEditPermission: false,

    /**
     * globalDestinationsEditPermission: whether the current user can edit this server's global Go To menu
     */
    globalDestinationsEditPermission: false,

    /**
     * activeFramesViewPermission - lists of all frames on this server with user counts
     */
    activeFramesViewPermission: false,

    /**
     * frameAdminPermission: whether the current user has admin permission on this frame to change this frame's settings, manage online users etc
     */
    frameAdminPermission: false,

    /**
     * frameOwnerPermission: whether the current user has ownerPermissions on this current frame to Delete frame, change what other admins can do etc
     */
    frameOwnerPermission: false,

    /**
     * isSinglePlayerMode: whether or not single player mode is enabled
     */
    isSinglePlayerMode: null,

    /**
     * portalDomains: used by portal only. array of who's allowed to access. (data type?)
     */
    portalDomains: [],

    /**
     * autoExpandedGotoMenu - whether or not the goto menu should be auto-expanded
     */
    autoExpandedGotoMenu: false,

    /**
     * staffDomains: array of staff domains (data type?)
     */
    staffDomains: [],

    /**
     * isExternalInterface: whether or not the user is using an external interface (use popups for links to mainline)
     */
    isExternalInterface: false,

    /**
     * mainlineDomain: the mainline domain (url base for frame links)
     */
    mainlineDomain: getMainlineDomain(),

    nametagsEnabled: true,
    /**
     * hardwareGranted: whether or not hardware permission is granted. This is the permissions from get user media
     */
    hardwareGranted: {
      microphone: false,
      camera: false,
      desktop: false,
    },

    /**
     * hardwareEnabled: whether or not hardware is enabled. This is not the same as getusermedia permissions becuase this toggles the use, even if permission is granted
     */
    hardwareEnabled: {
      microphone: false,
      camera: false,
      desktop: false,
    },

    /**
     * user: object containing id of the current logged-in user. data type?
     */
    user: {
      id: undefined,
    },

    /**
     * subscriptionsEnabled: whether or not subscriptions-related features are enabled.
     * gets set in https://github.com/virbela/frame/blob/babylon-develop/frame/webapp/core/dbSettings.ts#L23
     */
    subscriptionsEnabled: false,

    /**
     * tiers: the global definition of all subscription tiers available and their attributes. arrays of Tier.ts objects according to platform.
     */
    tiers: { dev: [], production: [] },

    /**
     * capabilities: the global capability definitions per each tier
     */
    capabilities: undefined, //these get loaded in from appSettings and are originally seeded via seed file.

    /**
     * avatar - Local avatar state. This is referenced when sending PeerIndicators to other peers
     */
    avatar: {
      id: "",
      lobby: true,
      nametag: "Guest",
      statusMessage: undefined,
      closedCaptionsEnabled: false,
      twitterURL: undefined,
      audioMuted: true,
      voiceZone: null,
      videoPanelEnabled: false,
      desktopVideoPanelEnabled: false,
      megaphoneEnabled: false,
      photo: undefined,
      isTyping: false,
      isPointing: false,
      pointerHand: "right",
      linkedInURL: undefined,
      immersProfileURL: undefined,
      immersId: undefined,
      handsEnabled: false,
      seatId: "none",
      isAdmin: false,
      isActive: true,
      email: undefined,
      isGuest: true,
      prefersLotus: false,
      isFlat: false,
      discEnabled: false,
      spectate: false,
      sitting: false,
      company: "",
      systemInfo: null,
      janusID: "",
      animations: [],
      supportRequestInfo: undefined,
    },

    /**
     * avatarId - avatar id. (?)
     */
    avatarId: undefined,

    /**
     * facade: data representing the outward appearance of the avatar, like their clothing configuration and avatar type (human, android, RPM)
     * in contrast to the avatar indicators data, which is information about the user like their nametag, if they are muted, if their megaphone is on, etc
     */
    facade: {
      avatarClass: "HomeomorphicAvatar",
      avatarUrl: "",
      type: "Android",
      bodyColor: "Blue",
      skinTone: "Tone_1",
      eyeColor: "Blue",
      hairStyle: "None",
      hairColor: "Black",
      hatColor: "Black",
      facialHairStyle: "None",
      glasses: "None",
      glassesColor: "Black",
      earrings: "None",
      accentColor: "VirBELA_Blue",
      pantsColor: "Navy",
      shoeColor: "Black",
      logo: "FrameLogo",
      jacket: "None",
      // fullbodyJacket: "Informal",
      jacketColor: "Black",
      gender: "Male",
      outfit: "Formal",
    },

    /**
     * boundAssets - the base model for the current frame
     */
    boundAssets: [],

    /**
     * avatarMenu - (legacy) babylon Avatar character customization screen
     */
    avatarMenu: {
      enabled: false,
      submenu: "android",
    },

    /**
     * activeCameraName - name of the currently active camera. possible values??
     */
    activeCameraName: "playerCam",

    /**
     * cameraMode - Avatar camera mode (first, third-person, etc.)
     */
    cameraMode: CameraMode.FirstPerson,

    /**
     * cameraRecenterMode: Avatar camera auto-recenter mode
     */
    cameraRecenterMode: CameraRecenterMode.AvatarToCamera,

    /**
     * isAssetOptionsBarVisible: whether certain UI/features are active/visible
     */
    isAssetOptionsBarVisible: false,

    /**
     * isConfirmDialogVisible: whether the confirmation dialog is visible
     */
    isConfirmDialogVisible: false,

    /**
     * Whether `avatarFullBodyLocked` has been enabled in `appSettings. This is used to determine
     * whether users should be able to toggle between Legacy (Floater) or Full-Body avatars.
     * There is also a frame-level prop of the same name used to determine this.
     */
    avatarFullBodyLocked: false,

    /**
     * Whether `disallowGuests` has been enabled in `appSettings` which disallows logged-out users.
     * Note that there is also a frame-level `disallowGuests` that takes precedence if more restrictive.
     */
    disallowGuests: false,

    /**
     * Set to `true` once `scene.onReadyObservable` fires (initial only)
     * Not to be confused with `babylonSceneLoaded` which is fired before the scene is ready
     */
    isBabylonSceneReady: false,

    /**
     * showEnvLabel: whether or not to show the environment label (?)
     */
    showEnvLabel: false,

    /**
     * isConnected: whether current user has connected to a frame. a change to false triggers a Frame exit
     */
    isConnected: false,
    isWebRTCReady: false,

    /**
     * hasEverConnected:  has the user been live in a room this session (useful for detecting transition between frames)
     */
    hasEverConnected: false,

    /**
     * usersList: list of users in the current frame. data type?
     */
    userList: [],

    /**
     * laserPointer: attributes for the laser pointer
     */
    laserPointer: {
      color: "#E92247",
    },

    /**
     * localVRPointer: attributes for the local VR Pointer
     */
    localVRPointer: {
      color: "#25afe3",
    },

    userRole: "guest",

    /**
     * sphereType: ?
     */
    sphereType: "",

    /**
     * isMenuExpanded: whether or not the menu (sidebar?) is expanded
     */
    isMenuExpanded: false,

    /**
     * expandedGoToEnabled: whether or not the expanded Go To menu is enabled
     */
    expandedGoToEnabled: false,

    /**
     * isGoToMenuExpanded: whether or not the Go To menu is expanded
     */
    isGoToMenuExpanded: false,

    /**
     * isRecording: whether or not the user is recording
     */
    isRecording: false,

    /**
     * streamMessage: ?
     */
    streamMessage: "",

    /**
     * streamStatus: string representing status of the stream (?) possible values?
     */
    streamStatus: "inactive",

    /**
     * streamTarget: string representing the current stream target (?) possible values?
     */
    streamTarget: "",

    /**
     * lookControlsDisabled: whether or not look controls are disabled
     */
    lookControlsDisabled: false,

    /**
     * spectatorModeEnabled: whether or not spectator mode is enabled
     */
    spectatorModeEnabled: false,

    /**
     * sceneResetAfterLastUser: whether or not to reset the scene after the last user leaves
     */
    sceneResetAfterLastUser: false,

    /**
     * rpmDisabled: whether or not RPM is disabled
     */
    rpmDisabled: false,

    /**
     * editObjectId: the id of the object currently being edited
     */
    editObjectId: null,

    /**
     * webcamEnabled: whether or not the webcam is enabled
     */
    webcamEnabled: false,

    /**
     * isSpectator: whether or not the user is a spectator
     */
    isSpectator: false,

    /**
     * vrEnabled: whether VR mode is enabled
     */
    vrEnabled: false,

    /**
     * vrImmersable: is this device capable of an "immersive-vr" WebXR session. Note: all android/chrome will report true for this even if all they support is cardboard mode regardless of whether the user actually possesses a cardboard viewer
     */
    vrImmersable: false,

    /**
     * handTrackingEnabled: whether or not hand tracking is enabled
     */
    handTrackingEnabled: false,

    /**
     * voiceInputLang: string representing the voice input language. possible values?
     */
    voiceInputLang: "en-US",

    /**
     * arrowKeysTurnUser - whether or not arrow keys turn the user, default to true for logged-out users
     */
    arrowKeysTurnUser: true,

    /**
     * avatarOptimizationOverrideEnabled: whether the avatar silhouette/indicator optimizations should be overridden, always displaying full avatars
     */
    avatarOptimizationOverrideEnabled: false,

    /**
     * clickToMove: whether or not click to move is enabled
     */
    clickToMove: true, //default to true

    /**
     * preferLotus: whether or not to prefer lotus seating position
     */
    prefersLotus: false,

    /**
     * allowSpeechRecognition - default null or undefined means prompt user
     */
    allowSpeechRecognition: null,

    /**
     * tutorialActive: (legacy) whether or not the tutorial is active
     */
    tutorialActive: false,

    /**
     * tutorialStep: (legacy) the current tutorial step
     */
    tutorialStep: 0,

    /**
     * connectionsServiceAvailable: whether or not the connections service is available
     */
    connectionsServiceAvailable: true,

    /**
     * showConnectionsActivation: whether or not to show the connections activation popup
     */
    showConnectionsActivation: false,
    doNotShowConnectionsActivation: false,

    /**
     * connectionsActivationAutoPopup: whether the activation popup opened automatically on connect
     */
    connectionsActivationAutoPopup: false,
    connectionsUsername: undefined,

    /**
     * signalinUrlSet: whether or not the signaling URL is set
     */
    signalingUrlSet: false,

    /**
     * domContentLoaded: whether or not the DOM content has loaded
     */
    domContentLoaded: false,

    /**
     * currentZoneName: Name of current voice zone (different from avatar.voiceZone which is unique id)
     */
    currentZoneName: null,

    /** baseVoiceZones - Base voice zones for quick. unknown purpose/incomplete type */
    baseVoiceZones: [],

    /**
     * currentZoneLockState: string representing whether the current zone locked or is it lockable by this user
     * possible values: @see ZoneLockState
     */
    currentZoneLockState: ZoneLockState.FORBIDDEN,

    /**
     * frameUpgradeDialogData (used for data within the upgrade dialog window)
     * missing data type
     */
    frameUpgradeDialogData: {
      /**
       * frameUpgradeDialog
       * true = upgrade dialog visible
       * false = upgrade dialog hidden
       */
      frameUpgradeDialog: false,
      frameToUpgrade: undefined,
      remix: false,
      clone: false,
      upgrade: false,
      cloneOptions: { copyMembers: false, copyAdmins: false },
      selectedTierId: 2,
      isAdminDialog: false,
    },

    /**
     * directCheckoutData (used for referral program and direct checkout links)
     * TODO: define data type
     */
    directCheckoutData: {
      /*
       * true = direct checkout dialog visible
       * false = direct checkout dialog hidden
       * (use zustand actions: showDirectCheckout, hideDirectCheckout)
       */
      directCheckout: false,
      frameToPurchase: {
        name: "",
        baseModel: undefined,
      },
      selectedTierId: 4,
    },

    /* sidebarTakeover:
     * true when sidebar takeover dialog visible
     * false when sidebar takeover dialog hidden
     * https://github.com/virbela/frame/wiki/Frame-Sidebar-Takeover-Mode-%5Bvue%5D
     */
    sidebarTakeover: false,

    /**
     * sidebarTakeoverComponentPath: string path to the component to load in sidebar takeover mode
     */
    sidebarTakeoverComponentPath: undefined,

    /**
     * interactivityDialog: the data used by the interactivityDialog
     * TODO: define data type
     */
    interactivityDialog: {
      show: false,
      assetId: undefined,
    },

    /**
     * loginMethods: the login methods
     */
    loginMethods: {
      email: false,
      google: false,
      microsoft: false,
      facebook: false,
      immers: false,
      custom: false,
    },
    /**
     * isChrome: whether or not the user is using chrome browser
     */
    isChrome:
      /Chrome/.test(navigator.userAgent) && /Google Inc/.test(navigator.vendor),

    /**
     * pickableMeshes: the pickable meshes, default null
     */
    pickableMeshes: null,
    nodeMaterials: new Map(),

    /**
     * modelsWithDirtyNodeMaterials: a map of models with dirty node materials. data type?
     */
    modelsWithDirtyNodeMaterials: new Map(),

    /**
     * pendingNotifications: array of the pending notifications (data type?)
     */
    pendingNotifications: [],

    /**
     * closedCaptionsUserCount: number of users with closed captions enabled
     */
    closedCaptionsUserCount: 0,

    // added because defined in GlobalStateStoreType but not here
    appSettingsBound: false,
    emojisOpen: false,
    isGlobalAdmin: false,
    disableLocationSharing: false,
    appSettingsID: "",
    claimedSpace: false,
    camPlacement: false,
    skyBoxGenerationStatus: "",
    api: { key: null, timestamp: null },
    draggingModelFromSidebar: false,
    snapModeEnabled: false,
    passwordSet: false,
    // app settings initial states
    alwaysSupportWidget: false,
    cacheRelease: { "all-cache": Timestamp.now() },
    creatorDomains: [],
    dateAdded: Timestamp.now(),
    defaultBrowserURL: "",
    globalDestinationCategories: [],
    staffDestinationCategories: [],
    announcement: undefined,
    staffAnnouncement: undefined,
    subBrandable: false,
    enableConnections: true,
    isChatSupportActive: false,
    audioPlayback: false,
    textAreaBeingEdited: "",
    mapEnvironments: false,
    mtsdfTextReady: false,
    /**
     *==============================================================================
     *   METHODS
     *==============================================================================
     * globally accessible methods that do not mutate state
     */
    /**
     * isCameraAttachedUIVisible: whether or not the camera attached UI is visible
     */
    isCameraAttachedUIVisible: () => {
      const {
        isAssetOptionsBarVisible,
        isConfirmDialogVisible,
        mainUIActive,
        isUserZoomedIn,
      } = get();

      return (
        isAssetOptionsBarVisible ||
        isConfirmDialogVisible ||
        mainUIActive ||
        isUserZoomedIn
      );
    },

    /**
     * thirdPersonCameraEnabled: Whether the user has ENABLED ThirdPersonCamera (may not be active)
     */
    thirdPersonCameraEnabled: () => {
      return get().cameraMode === CameraMode.ThirdPerson;
    },
    /**
     * thirdPersonCameraActive:
     * Whether the ThirdPersonCamera is currently active (not to be confused with enabled)
     * ThirdPersonCamera will be forced inactive under specific state conditions
     */
    thirdPersonCameraActive: () => {
      const {
        isConnected,
        canConnectAsSinglePlayer,
        isCurrentFrameOwned,
        thirdPersonCameraEnabled,
        isCameraAttachedUIVisible,
        isSpectator,
        vrEnabled,
        sitting,
        shouldDisplayAvatarBuilder,
      } = get();

      return (
        shouldDisplayAvatarBuilder() ||
        (thirdPersonCameraEnabled() &&
          !isCameraAttachedUIVisible() &&
          isCurrentFrameOwned() &&
          (isConnected || canConnectAsSinglePlayer()) &&
          !isSpectator &&
          !vrEnabled &&
          !sitting)
      );
    },

    /**
     * shouldDisplayQuickUI
     *  QuickUI should be created/displayed?
     */
    shouldDisplayQuickUI: () => {
      const {
        isBabylonSceneReady,
        isCurrentFrameOwned,
        isConnected,
        isSinglePlayerMode,
        isSpectator,
        vrEnabled,
      } = get();

      return (
        isBabylonSceneReady &&
        isCurrentFrameOwned() &&
        (isConnected || !!isSinglePlayerMode) &&
        !isSpectator &&
        !vrEnabled
      );
    },

    /**
     * isCurrentFrameOwned:
     * Used to determine if a Frame is claimed.
     * We can do a negated check of this to determine if a Frame is unclaimed
     * for lack of a better alternative at this time.
     * @returns `boolean` representing whether the owner is not `"none"` (unclaimed)
     */
    isCurrentFrameOwned: () => {
      return get().frame.owner !== "none";
    },

    /**
     * restrictAllAssetsToZones:
     * Whether all assets should be forced to be private to their respective PVZs
     * Top-level state action to allow for factoring in performance overrides
     * @returns `boolean` representing whether assets should be restricted
     */
    restrictAllAssetsToZones: () => {
      return get().frame.restrictAllAssetsToZones;
    },

    /**
     * Whether conditions are met to allow obstructive Babylon UI to be displayed
     * TODO: This is not fully supported across all UI, but handles most obstructive cases
     * @returns `boolean` representing whether UI should be displayed
     */
    canDisplayObstructiveBabylonUI: () => {
      return !get().shouldDisplayAvatarBuilder();
    },

    /**
     * shouldDisplayConnectUI:
     * Checks whether the Connect UI should be displayed (not including password input)
     * @returns `boolean` whether Connect UI should be displayed
     */
    shouldDisplayConnectUI: () => {
      const {
        isConnected,
        isPasswordSatisfied,
        canConnectAsSinglePlayer,
        canDisplayObstructiveBabylonUI,
        mainUIActive,
      } = get();

      return (
        canDisplayObstructiveBabylonUI() &&
        isPasswordSatisfied() &&
        !isConnected &&
        !canConnectAsSinglePlayer() &&
        !mainUIActive
      );
    },

    /**
     * Whether the Password protection UI should be displayed
     * @returns `boolean` whether the Password UI should be displayed
     */
    shouldDisplayPasswordUI: () => {
      return (
        get().canDisplayObstructiveBabylonUI() &&
        !get().isPasswordSatisfied() &&
        !get().mainUIActive
      );
    },

    /**
     * isPasswordSatisfied:
     * Checks whether the frame password is satisfied if set
     * @returns `boolean` whether the password is satisfied if set; `true` if not set.
     */
    isPasswordSatisfied: () => {
      const { passwordSet, frame } = get();
      return !!(frame.password ? passwordSet : true);
    },

    /**
     * isPeerCountWithinLimit:
     * Checks whether the peer count is within limit
     * TODO: this needs to be updated to use the correct counters under the frame object
     * @returns `boolean` whether within user count limit
     */
    isPeerCountWithinLimit: () => {
      const { participantCount, frame } = get();
      return participantCount < frameCapabilityValue(frame, "peerMax");
    },

    /**
     * isSpectatorCountWithinLimit:
     * Checks whether the spectator count is within limit
     * TODO: this needs to be updated to use the correct counters under the frame object
     * @returns `boolean` whether within spectator count limit
     */
    isSpectatorCountWithinLimit: () => {
      const {
        spectatorCount,
        frame: { spectatorMax },
      } = get();
      return spectatorCount < spectatorMax;
    },

    /**
     * isReadyForConnectUI:
     * Checks whether base conditions are met to connect
     * before considering permissions and user/spectator limits
     * @returns `boolean` whether basic connect conditions are met
     */
    isReadyForConnectUI: () => {
      const {
        frameBound,
        isConnected,
        quickTraverse,
        baseModelLoaded,
        isCurrentFrameOwned,
      } = get();
      return (
        !isConnected &&
        frameBound &&
        baseModelLoaded &&
        !quickTraverse &&
        isCurrentFrameOwned()
      );
    },

    /**
     * canConnectAsUser:
     * Checks whether conditions are met to connect as standard user
     * @returns `boolean` whether user is allowed to connect as a user
     */
    canConnectAsUser: () => {
      const {
        viewPermission,
        isReadyForConnectUI,
        isSinglePlayerMode,
        isPasswordSatisfied,
        isPeerCountWithinLimit,
        isWebRTCReady,
      } = get();

      return (
        viewPermission &&
        !isSinglePlayerMode &&
        isWebRTCReady &&
        isReadyForConnectUI() &&
        isPasswordSatisfied() &&
        isPeerCountWithinLimit()
      );
    },

    /**
     * canConnectAsSpectator: Checks whether conditions are met to connect as a spectator
     * @returns `boolean` whether user is allowed to connect as a spectator
     */
    canConnectAsSpectator: () => {
      const {
        frame,
        viewPermission,
        isReadyForConnectUI,
        isSinglePlayerMode,
        isPasswordSatisfied,
        isSpectatorCountWithinLimit,
        isWebRTCReady,
      } = get();

      return (
        frame.spectatorModeEnabled &&
        viewPermission &&
        !isSinglePlayerMode &&
        isWebRTCReady &&
        isReadyForConnectUI() &&
        isPasswordSatisfied() &&
        isSpectatorCountWithinLimit()
      );
    },

    /**
     * canConnectAsSinglePlayer:
     * Checks whether the user can connect as a single player/user
     * @returns `boolean` whether single player access is allowed
     */
    canConnectAsSinglePlayer: () => {
      const {
        viewPermission,
        isReadyForConnectUI,
        isSinglePlayerMode,
        isPasswordSatisfied,
      } = get();

      return (
        viewPermission &&
        !!isSinglePlayerMode &&
        isReadyForConnectUI() &&
        isPasswordSatisfied()
      );
    },

    /**
     * isChromeDesktop: Checks if the user is using Chrome on desktop
     * @returns boolean
     */
    isChromeDesktop: () => get().isChrome && !get().vrImmersable,

    /**
     * micBlockedFromFrame
     * @returns boolean
     */
    micBlockedFromFrame: () => !get().micPermission,

    /**
     * camBlockedFromFrame
     * @returns boolean
     */
    camBlockedFromFrame: () => !get().cameraPermission,

    /**
     * streamScreensDisabled
     * @returns boolean
     */
    streamScreensDisabled: () => !get().streamingPermission,

    /**
     * micGranted
     * @returns boolean
     */
    micGranted: () => get().hardwareGranted.microphone,

    /**
     * hasHomeAccess
     * @returns boolean
     */
    hasHomeAccess: () => {
      if (get().portalDomains && get().portalDomains.length > 0) {
        const approvedDomains = get().portalDomains;
        const emailDomain = get().email.replace(/^.*@/i, "");
        return approvedDomains.indexOf(emailDomain) !== -1;
      }
      return true;
    },

    /**
     * isStaff
     * @returns boolean
     */
    isStaff: () => {
      if (get().isDeveloper || get().isGlobalAdmin) {
        return true;
      }
      if (get().staffDomains) {
        const domains = get().staffDomains;
        const emailDomain = get().email.replace(/^.*@/i, "");
        return domains.indexOf(emailDomain) !== -1;
      }
      return false;
    },

    /**
     * ==============================================================================
     *      ACTIONS
     * ==============================================================================
     * zustand actions which modify state data.
     * https://docs.pmnd.rs/zustand/guides/practice-with-no-store-actions
     */
    setAvatar: (avatar) =>
      set((state) => ({ avatar: { ...state.avatar, ...avatar } })),
    /**
     * addNotification
     * @returns void
     */
    addNotification: (notif) =>
      set({ pendingNotifications: [...get().pendingNotifications, notif] }),

    setCloneOptions: ({ copyMembers = undefined, copyAdmins = undefined }) => {
      const newCloneOptions = { ...get().frameUpgradeDialogData.cloneOptions };
      if (copyMembers !== undefined) {
        newCloneOptions.copyMembers = copyMembers;
      }
      if (copyAdmins !== undefined) {
        newCloneOptions.copyAdmins = copyAdmins;
      }

      set({
        frameUpgradeDialogData: {
          ...get().frameUpgradeDialogData,
          cloneOptions: newCloneOptions,
        },
      });
    },

    showUpgradeDialog: ({
      frame = get().frame,
      selectedTierId = undefined,
      remix = false,
      clone = false,
      upgrade = false,
      isAdminDialog = false,
    }) => {
      //if this is an upgrade of an existing frame, set selectedTierId to the current frame's tier id.
      if (!selectedTierId) {
        selectedTierId = frame?.frameTierId ?? 1;
      }

      set({
        frameUpgradeDialogData: {
          selectedTierId,
          frameToUpgrade: frame, // "frameToUpgrade" is the frame to operate one whether doing  a clone, remix, or upgrade
          remix,
          clone,
          upgrade,
          isAdminDialog,
          /* if state.frameToUpgrade is not set, FrameUpgradeDialog component will use
              the current frame in context as the "frameToUpgrade" */
          frameUpgradeDialog: true,
        },
      });
    },

    hideUpgradeDialog: () =>
      /* upon hiding the dialog, clear whichever frame was specified as the frame to upgrade. */

      set({
        frameUpgradeDialogData: {
          frameToUpgrade: undefined,
          frameUpgradeDialog: false,
          selectedTierId: undefined,
          remix: false,
          clone: false,
        },
      }),

    setSelectedTierId: ({ selectedTierId }) =>
      set({
        frameUpgradeDialogData: {
          ...get().frameUpgradeDialogData,
          selectedTierId,
        },
      }),

    showDirectCheckout: () => {
      // close any welcome notifications as they are cluttered and not relevant yet during direct checkout

      set({
        directCheckoutData: {
          directCheckout: true,
          // set to defaults
          frameToPurchase: {
            name: "",
            baseModel: undefined,
          },
          selectedTierId: 4,
        },
      });
    },

    hideDirectCheckout: () => {
      set({
        directCheckoutData: {
          directCheckout: false,
          // set to defaults
          frameToPurchase: {
            name: "",
            baseModel: undefined,
          },
          selectedTierId: 4,
        },
      });
    },

    setDirectCheckoutFrameData: (newFrameData) => {
      set({
        directCheckoutData: {
          ...get().directCheckoutData,
          frameToPurchase: newFrameData,
        },
      });
    },

    setDirectCheckoutTierId: (newId) => {
      console.log();
      set({
        directCheckoutData: {
          ...get().directCheckoutData,
          selectedTierId: newId,
        },
      });
    },

    showInteractivityDialog: (assetId) =>
      set({
        interactivityDialog: {
          show: true,
          assetId,
        },
      }),

    hideInteractivityDialog: () =>
      set({
        interactivityDialog: {
          show: false,
          assetId: undefined,
        },
      }),

    setTutorialStep: (step) => {
      set({ tutorialStep: step });
    },

    nextTutorialStep: () => {
      get().setTutorialStep(get().tutorialStep + 1);
    },

    previousTutorialStep: () => {
      get().setTutorialStep(get().tutorialStep - 1);
    },

    activateTutorial: () => {
      set({ tutorialActive: true });
      get().setTutorialStep(0);
    },

    deactivateTutorial: () => {
      set({ tutorialActive: false });
      set({ tutorialStep: 0 });
    },

    toggleTutorial: () => {
      set({ tutorialActive: !get().tutorialActive });
    },

    updateClosedCaptionsUserCount: (increment) => {
      set({
        closedCaptionsUserCount: get().closedCaptionsUserCount + increment,
      });
    },

    toggleSidebar: () => {
      set({ isSidebarOpen: !get().isSidebarOpen });
    },

    openSidebar: () => {
      set({ isSidebarOpen: true });
    },

    closeSidebar: () => {
      set({ isSidebarOpen: false });
    },

    /** which tab of spaces panel should be expanded */
    showSpacesPanelOnce: -1,

    sidebarTakeoverMode: (componentPath) => {
      //it's up to the sidebar takeover component to determine if requested components to load in the sidebar exist.
      set({
        isSidebarOpen: true,
        sidebarTakeover: true,
        sidebarTakeoverComponentPath: componentPath,
      });
    },

    closeSidebarTakeover: () => {
      set({ sidebarTakeover: false });
    },

    /** Enables the vue avatar builder */
    showAvatarBuilder: () => {
      get().hideSidebar();
      set({ avatarBuilder: true });
    },
    /** hideSidebar
     * hides the main frame sidebar
     */
    hideSidebar: () => {
      set({ isSidebarOpen: false });
    },
    /** Disables the vue avatar builder */
    hideAvatarBuilder: () => {
      set({ avatarBuilder: false });
    },
    /** Whether the Vue Avatar Builder should be displayed */
    shouldDisplayAvatarBuilder: () => {
      return get().avatarBuilder && !get().isConfirmDialogVisible;
    },
    /**
     * Toggles the Vue Avatar Customization UI (new)
     * This is used in state; use `toggleAvatarCustomization` in client code
     */
    toggleAvatarBuilder: () => {
      get().avatarBuilder
        ? get().hideAvatarBuilder()
        : get().showAvatarBuilder();
    },
    /**
     * Toggles the Babylon Avatar Customization UI (legacy)
     * This is used in state; use `toggleAvatarCustomization` in client code
     */
    toggleAvatarBuilderLegacy: () => {
      const { mainUIActive, mainUIPanel } = get();
      set({
        mainUIActive: mainUIPanel !== "AVATAR" || !mainUIActive,
        mainUIPanel: "AVATAR",
      });
    },
    /**
     * Toggles appropriate Avatar Customization based on conditions
     * TODO: This will later be updated to allow for new builder pre-connect
     */
    toggleAvatarCustomization: () => {
      get().vrEnabled
        ? get().toggleAvatarBuilderLegacy()
        : get().toggleAvatarBuilder();
    },

    /**
     * Whether the Babylon Avatar UI (legacy) is active
     * @returns `boolean` whether the UI is active
     */
    isAvatarBuilderLegacyActive: () => {
      return get().mainUIActive && get().mainUIPanel === "AVATAR";
    },

    /**
     * Whether the Full Body Avatars toggle should be disabled. This checks both app-level
     * and frame-level versions of `avatarFullBodyLocked`.
     */
    disableAvatarBodyToggle: () => {
      return get().avatarFullBodyLocked || get().frame.avatarFullBodyLocked;
    },
  }))
);

export default stateManager;

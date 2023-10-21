import {
  frameCreate,
  frameHydrate,
  frameHydrateUnclaimed,
  frameUpdateCapabilityValue,
} from "@core/utils/Frame";
import { IFrameBaseModel } from "./types/BaseModel";
import { GlobalStateStoreType } from "./state-utils";
import { database } from "./database";
import { setupScenes } from "./dbScenes";
import { setupDestinations } from "./dbDestinations";
import { setupChats, setupPrivateChats } from "./dbChats";
import {
  doc,
  where,
  collection,
  setDoc,
  query,
  getDoc,
  getDocs,
  onSnapshot,
  serverTimestamp,
  DocumentData,
  Query,
  Unsubscribe,
} from "firebase/firestore";
import SM from "./state";
import { UserStore } from "./stores/UserStore";
import { setAvatar } from "./stateHandlers.js";
import { randomAlphaString } from "./utils/randomAlphaString";
import { updateUserPermissions } from "./permissions";
import { getAuth } from "firebase/auth";
import { IFrameUpdate } from "./types/Frame";
import { baseModelStateHydrate } from "./utils/BaseModel";

const stateManager: GlobalStateStoreType = SM;

let unsub: Unsubscribe;

const FRAME_NAME_VALIDATION_REGEX = /^[a-z][a-z\d-]*$/;
const FRAME_NAME_WITH_SPAWN_SPOT_VALIDATION_REGEX = /^[a-z][a-z\d-]*[#]?.*$/;

/**
 * Lookup frame by name, return query reference
 */
function getFrameByName(frameName: string): Query<DocumentData> {
  return query(
    collection(database, "spaces"),
    where("spaceID", "==", frameName)
  );
}

async function frameNameExists(frameName: string): Promise<boolean> {
  const spaceDoc = await getDocs(getFrameByName(frameName));
  return !spaceDoc.empty;
}

function bindFrameToState(frameName: string): void {
  if (unsub) {
    unsub();
  }
  let isSinglePlayerMode = stateManager.getState().isSinglePlayerMode;
  let firstLoad = true;
  let currentlyAdmin = false;

  //Get frame database object
  const frame = getFrameByName(frameName || "");
  unsub = onSnapshot(frame, (frameData) => {
    if (frameData.empty) {
      if (isSinglePlayerMode !== null) {
        // transitioned here from another frame, reload required
        window.location.reload();
      }
      stateManager.setState({
        userRole: "guest",
        viewPermission: true,
        editPermission: false,
        interactPermission: true,
        frame: frameHydrateUnclaimed({
          spaceID: frameName,
        }),
        frameBound: true,
        isSinglePlayerMode: true,
        baseModel: baseModelStateHydrate({ title: "Gallery (Small)" }),
      });
    } else {
      //Can we drop the foreach here?
      frameData.forEach(async function (frameDoc) {
        if (isSinglePlayerMode === null) {
          isSinglePlayerMode = frameDoc.data().isSinglePlayerMode;
        } else if (
          // reload if single player was changed by another user (or admin dash),
          // else refresh will be triggered by updater after finished saving
          (isSinglePlayerMode !== !!frameDoc.data().isSinglePlayerMode &&
            !frameData.metadata.hasPendingWrites) ||
          // transition from special frame (empty/vanilla) requires reload
          stateManager.getState().frame?.owner === "none"
        ) {
          window.location.reload();
        }

        const auth = getAuth();
        const { isConnected, isGlobalAdmin, disallowGuests } =
          stateManager.getState();
        const { permissions, stateOverrides } = updateUserPermissions(
          auth,
          frameDoc.data(),
          isConnected,
          isGlobalAdmin,
          disallowGuests
        );

        // fill in defaults and types to the firestore data
        const frameToBind = frameHydrate(frameDoc.data());
        /* 
          Prepare the correct metadata based upon the state
          of fullbodies enabled.
          */
        const baseModel = baseModelStateHydrate(
          frameToBind.baseModel,
          frameToBind.fullBodiesEnabled
        );
        if (frameDoc.data().customNavMesh) {
          baseModel.navMesh = frameDoc.data().customNavMesh;
        }
        isSinglePlayerMode = !!frameDoc.data().isSinglePlayerMode;

        // does frame have frame.peerMax? convert to capabilityValue.
        if (frameDoc.data().peerMax) {
          //does the current frame.peerMax match a known allowed capabilityValue?
          const matchingCV = stateManager
            .getState()
            .capabilities?.peerMax?.values?.find((cv) => {
              return (
                cv.slug == "peerMax" && cv.value == frameDoc.data().peerMax
              );
            });

          if (matchingCV) {
            // a legacy property is set to a known allowed capabilityValue!
            // update this frame's capability values and deprecate the legacy field
            frameUpdateCapabilityValue(
              frameToBind,
              {
                ["peerMax"]: matchingCV.value,
              },
              true /* flag to deprecate the legacy property when done! */
            );
          }
        }

        stateManager.setState((state) => ({
          ...permissions,
          claimedSpace: true,
          backgroundAssets: frameDoc.data().backgroundAssets,
          backgroundPhotosphere: frameDoc.data().backgroundPhotosphere,
          expandedGoToEnabled: frameDoc.data().expandedGoToEnabled,
          privateChatEnabled: !frameDoc.data().privateChatDisabled,
          baseModel,
          frameOwner: frameDoc.data().owner,
          isSinglePlayerMode,
          frame: frameToBind,
          frameBound: true,
          activeSlideId: frameDoc.data().activeSlideId,
          activeSlide: state.slides.find(
            (slide) => slide.id === frameDoc.data().activeSlideId
          ),
          // If sky undefined, use default state, gabe recently moved this to frame state where it should be
          //sky: frameDoc.data().sky ?? state.sky,
          // disable fly mode if permission is removed
          flyModeOn: frameDoc.data().flyModeAllowed ? state.flyModeOn : false,
          ...stateOverrides,
        }));

        if (firstLoad) {
          setupScenes(
            frameDoc.ref.path,
            frameDoc.data().owner,
            frameDoc.data().spaceID,
            frameDoc.data().slidesVersion,
            frameDoc.data().orderedSlides
          );
          setupDestinations(frameDoc.ref.path, false);
          setupChats(frameDoc.data().spaceID);
          setupPrivateChats(stateManager.getState().userID);
          firstLoad = false;
        }
        if (permissions.frameAdminPermission !== currentlyAdmin) {
          currentlyAdmin = permissions.frameAdminPermission;
          setAvatar({
            isAdmin: currentlyAdmin,
          });
        }
      });
    }
  });
}

function unbindFrameFromState(): void {
  if (unsub) {
    unsub();
  }
  // due to limitations in transitions between single/multi, preserve last state
  const { isSinglePlayerMode } = stateManager.getState().frame;
  const frame = frameCreate({
    isSinglePlayerMode,
    baseModel: { title: "Empty" },
  });
  stateManager.setState({
    userRole: "guest",
    viewPermission: true,
    editPermission: false,
    interactPermission: false,
    frameBound: false,
    baseModelLoaded: false,
    // pause render loop until frame is bound again
    babylonSceneLoaded: false,
    frame,
    baseModel: baseModelStateHydrate(frame.baseModel),
  });
}

function isValidFrameName(frameName: string): boolean {
  // lowercase, digits, hyphens only
  return !!frameName.match(FRAME_NAME_VALIDATION_REGEX);
}

function isValidFrameNameWithSpawnSpot(frameName: string): boolean {
  // lowercase, digits, hyphens only
  return !!frameName.match(FRAME_NAME_WITH_SPAWN_SPOT_VALIDATION_REGEX);
}

/**
 * Create persistent frame in the database,
 * Owned by the currenly firebase-authenticated user
 *
 * @param {string} frameName
 * @param {object} options
 *  - baseModel - basemodel information
 *  - skipFrameCountCheck - boolean - skips current user free frame count check
 *  - spectatorModeEnabled - boolean
 *
 * @return Promise resolve/reject, or throws the following errors
 *   - reasons:
 *     - noFreeTierFrames - subscriptiopns enabled, and out of free frames
 *     - invalid name - see isValidFrameName
 *     - invalidDomain - frame creator domains (appsettings) enabled and user's email isnt in the creator domain list.
 *     - conflict - frame with same name already exists
 */
async function createFrame(
  frameName: string,
  options: {
    skipFrameCountCheck?: boolean;
    baseModel?: IFrameBaseModel;
    spectatorModeEnabled?: boolean;
  } = {}
): Promise<void> {
  // check free tier count
  const { isDeveloper, subscriptionsEnabled, maxFrames } =
    stateManager.getState();
  const freeFrameCount =
    UserStore.getState().userFrames.filter((frame) => frame.frameTierId === 1)
      .length ?? 0;
  if (
    !options.skipFrameCountCheck &&
    !isDeveloper &&
    subscriptionsEnabled &&
    freeFrameCount >= maxFrames
  ) {
    throw new Error("noFreeTierFrames");
  }

  const correctName = frameName.toLowerCase();
  if (!isValidFrameName(correctName)) {
    throw new Error("invalid name");
  }
  const userId = stateManager.getState().userID;

  //Check if user has the right domains to create frame
  // If there are no creatorDomains, its disabled
  // If enabled, only users matchng the domains provided will
  //  be able to create frames and non-logged in users can not.
  // NOTE: This is client side security and is not good.
  if (stateManager.getState().creatorDomains.length) {
    const approvedDomains = stateManager
      .getState()
      .creatorDomains.concat([window.location.host]);
    const userDomain = stateManager.getState().email.split("@")[1];
    if (!userDomain || !approvedDomains.includes(userDomain)) {
      throw new Error("invalidDomain");
    }
  }

  const conflictCheck = query(
    collection(database, "spaces"),
    where("spaceID", "==", correctName)
  );

  // Get this frame from the databse
  //Check if this frame exists
  const spaceDoc = await getDocs(conflictCheck);
  if (spaceDoc.empty) {
    //If this frame doesn't exist, claim is as the current users frame
    const slideId = randomAlphaString();

    const defaultFrameSettingsFromAppSettings =
      stateManager.getState().defaultFrameSettings ?? {};

    const newFrameSettings: Partial<IFrameUpdate> = {
      spaceID: correctName,
      spaceURL: "https://framevr.io/" + correctName,
      owner: userId,
      db: { lastUpdated: serverTimestamp(), version: 2.0 },
      spectatorModeEnabled: options.spectatorModeEnabled || false,
      /** Set default new frame tiers to 3 for subscriptionEnabled: false whitelabel instances of the app. required to get correct Capabilities. */
      frameTierId: subscriptionsEnabled ? 1 : 3,
      lastModified: serverTimestamp(),
      createdAt: serverTimestamp(),
      lastVisited: serverTimestamp(),
      activeSlideId: slideId,
    };
    if (options.baseModel) {
      newFrameSettings.baseModel = options.baseModel;
    }

    await setDoc(
      doc(database, "spaces", correctName),
      frameCreate(
        Object.assign(newFrameSettings, defaultFrameSettingsFromAppSettings)
      )
    );

    await setDoc(doc(database, "spaces", correctName, "slides", slideId), {
      title: "Untitled",
      currentPhotosphere: "none",
      order: 0,
      id: slideId,
    });

    //Create the frame distributed counter
    // addDoc(collection(database, "frames"), {
    //   name: correctName
    // });
    Promise.resolve();
  } else {
    throw new Error("conflict");
  }
}

async function getDefaultSpawnSpotName(
  frameName: string
): Promise<string | null> {
  const querySnapshot = await getDocs(
    query(
      collection(database, "spaces", frameName, "spawn-spots"),
      where("defaultSpot", "==", true)
    )
  );

  return querySnapshot.empty ? null : querySnapshot.docs[0].data().name;
}

/**
 * getframe owner email
 */
async function getOwnerEmail(
  spaceId: string
): Promise<string | undefined | null> {
  const spaceDoc = (await getDoc(doc(database, "spaces", spaceId))).data();
  if (!spaceDoc) {
    return undefined;
  }
  const ownerId = spaceDoc.owner;
  if (!ownerId) {
    return null;
  }
  const profileDoc = (await getDoc(doc(database, "users", ownerId))).data();
  if (!profileDoc) {
    return null;
  }
  return profileDoc.email;
}

export default {
  FRAME_NAME_VALIDATION_REGEX,
  FRAME_NAME_WITH_SPAWN_SPOT_VALIDATION_REGEX,
  getFrameByName,
  frameNameExists,
  bindFrameToState,
  unbindFrameFromState,
  isValidFrameName,
  isValidFrameNameWithSpawnSpot,
  createFrame,
  getDefaultSpawnSpotName,
  getOwnerEmail,
};

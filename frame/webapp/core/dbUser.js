import { database } from "./database";
import branding from "./branding";
import stateManager from "./state";
import { setAvatar, setFacade } from "./stateHandlers";
import { updateStateProfileFeatures } from "./userProfileFeatures";
import { immersClient, syncProfileToFrame } from "./immers";
import {
  query,
  collection,
  addDoc,
  where,
  updateDoc,
  getDocs,
  Timestamp,
} from "firebase/firestore";
import equal from "deep-equal";
import { UserStore } from "./stores/UserStore";
import { User } from "./types/User";
import { frameHydrate } from "@core/utils/Frame";

import defaultAsset_Dog from "../stage/models/dog.glb?staticUrl";
import defaultAsset_Image from "../stage/img/inventoryassets/FrameImage.jpg?staticUrl";
import defaultAsset_PhotoSphere1 from "../stage/img/inventoryassets/Outdoors.jpg?staticUrl";
import defaultAsset_PhotoSphere2 from "../stage/img/inventoryassets/Paris.jpg?staticUrl";
import {
  CLOUDINARY_FRAME_CDN_URL_HTTPS,
  PROFILE_PHOTO_OPTIMIZATIONS,
  cloudinaryStringSlice,
  getUpdatedCloudinaryUrl,
} from "./utils/cloudinaryStringSlice";
import {
  getAuth,
  createUserWithEmailAndPassword,
  sendEmailVerification,
  fetchSignInMethodsForEmail,
  signInWithEmailAndPassword,
  GoogleAuthProvider,
  getAdditionalUserInfo,
  signInWithPopup,
  signInWithCustomToken,
  OAuthProvider,
  onAuthStateChanged,
  FacebookAuthProvider,
  sendPasswordResetEmail,
  signOut,
  linkWithPopup,
  reload,
} from "firebase/auth";
import { doc, setDoc, serverTimestamp, onSnapshot } from "firebase/firestore";
import { updateUserPermissions } from "./permissions";
import { CameraMode, CameraRecenterMode } from "./CameraModeManager";
import { v4 as uuidv4 } from "uuid";
import { setupPrivateChats, disconnectPrivateChats } from "./dbChats";
import webappCredentials from "../credentials.json";

const PROFILE_STATE_PROPS = {
  maxFrames: "maxFrames",
  textChatLang: "textChatLang",
  voiceInputLang: "voiceInputLang",
  isTutorialActive: "tutorialActive",
  createdTime: "userCreatedTimestamp",
  disableLocationSharing: "disableLocationSharing",
  doNotShowConnectionsActivation: "doNotShowConnectionsActivation",
  isGlobalAdmin: "isGlobalAdmin",
  stripe_customer_id: "stripe_customer_id",
  apiKeys: "apiKeys",
  shareSensitiveInfoWithExternalAPICall:
    "shareSensitiveInfoWithExternalAPICall",
  // connectionsUsername - special handling below to extract deep property
  // isChatSupportActive - special handling below to check frame ownership
};
// profile photo not included due to special handling (deep property, url modification)
const PROFILE_AVATAR_PROPS = {
  nametag: "nametag",
  statusMessage: "statusMessage",
  linkedInURL: "linkedInURL",
  twitterURL: "twitterURL",
  company: "company",
  prefersLotus: "prefersLotus",
};
let unsubProfile;
let unsubUserFrames;
let unsubMemberFrames;
let unsubUserAdminFrames;
let previousAvatarUpdate;

export class TooManyUserFrames extends Error {}
export class InvalidFrameName extends Error {}
export class FrameNameConflict extends Error {}

export class MaxUserReloads extends Error {}

//Link accounts between other oauth accounts
export default {
  reloadInterval: null,

  logout: function () {
    return signOut(getAuth());
  },
  linkUserAccount: async function (currentProvider, linkingProviderString) {
    let linkingProvider;
    if (linkingProviderString === "google.com") {
      linkingProvider = new GoogleAuthProvider();
    }

    //Associate the current user to the provider
    await linkWithPopup(currentProvider, linkingProvider)
      .then((/*result*/) => {
        // Accounts successfully linked.
        //console.log("More results", result);
        //const credential = GoogleAuthProvider.credentialFromResult(result);
        //const user = result.user;
      })
      .catch((error) => {
        // Handle Errors here.
        console.log("Error associating account", error);
      });
  },

  login_usernamepassword: function (email, password) {
    const auth = getAuth();
    return createUserWithEmailAndPassword(auth, email, password)
      .then(
        async (userCredential) => {
          const user = userCredential.user;
          if (!user.emailVerified) {
            sendEmailVerification(user);
          }
          window.plausible("Sign Up", {
            props: { method: "email" },
          });

          return {
            isExistingUser: false,
            emailVerified: user.emailVerified,
          };
        },

        (error) => {
          let errorCode = error.code;
          if (errorCode == "auth/email-already-in-use") {
            //If already in use, just try to sign in.
            return signInWithEmailAndPassword(auth, email, password).then(
              (userCredential) => {
                this.trackReturningLogin("email", userCredential.user.uid);
                return {
                  isExistingUser: true,
                  emailVerified: userCredential.user.emailVerified,
                };
              }
            );
          }
          throw error;
        }
      )
      .catch((err) => {
        alert("Oops. " + err.message);
        throw err;
      });
  },

  login_google: function () {
    const auth = getAuth();
    const provider = new GoogleAuthProvider();

    signInWithPopup(auth, provider)
      .then((result) => {
        const additionalUserInfo = getAdditionalUserInfo(result);
        if (additionalUserInfo.isNewUser) {
          window.plausible("Sign Up", {
            props: { method: "Google" },
          });
        } else {
          this.trackReturningLogin("Google", result.user.uid);
        }
      })
      .catch((err) => {
        alert("Oops. " + err.message);
      });
  },

  login_microsoft: function () {
    const auth = getAuth();
    const provider = new OAuthProvider("microsoft.com");

    signInWithPopup(auth, provider)
      .then((result) => {
        const additionalUserInfo = getAdditionalUserInfo(result);
        if (additionalUserInfo.isNewUser) {
          window.plausible("Sign Up", {
            props: { method: "Microsoft" },
          });
        } else {
          this.trackReturningLogin("Microsoft", result.user.uid);
        }
      })
      .catch(async (error) => {
        console.log("MSLOGIN Error!", error.code);
        if (error.code != "auth/account-exists-with-different-credential") {
          throw error;
        }

        if (error.customData.email.endsWith("onmicrosoft.com")) {
          alert("*.onmicrosoft.com development domains are not supported.");
          return;
        }

        let methods = await fetchSignInMethodsForEmail(
          getAuth(),
          error.customData.email
        );

        this.linkUserAccount(provider, methods[0]);
      });
  },

  login_facebook: function () {
    const auth = getAuth();
    const provider = new FacebookAuthProvider();
    signInWithPopup(auth, provider)
      .then((result) => {
        const additionalUserInfo = getAdditionalUserInfo(result);
        if (additionalUserInfo.isNewUser) {
          window.plausible("Sign Up", {
            props: { method: "Facebook" },
          });
        } else {
          this.trackReturningLogin("Facebook", result.user.uid);
        }
      })
      .catch((err) => {
        alert("Oops. " + err.message);
      });
  },

  login_immers: async function (handle) {
    let token;
    let profile;
    let firebaseToken;
    try {
      token = await immersClient.login(
        window.location.href,
        "modAdditive",
        // grab handle from cache if this is a reconnect
        handle ?? immersClient.handle
      );
      profile = immersClient.profile;
    } catch (error) {
      console.error("Error logging into Immers account: ", error.message);
      return;
    }
    try {
      const response = await fetch(
        stateManager.getState().apiURL + "/auth/firebase/immers",
        {
          method: "post",
          body: JSON.stringify({
            token,
            id: profile.id,
            // e-mail is available only with fresh SSO logins
            email: immersClient.sessionInfo.email,
          }),
        }
      );
      if (response.status === 400) {
        console.warn("Could not complete SSO login due to missing e-mail");
        // attempted SSO login failed due to no matching firebase acct and no email
        // available in current immersClient session. Reset immers session to get
        // email from SSO provider
        await immersClient.logout(true);
        throw new Error("Missing e-mail");
      } else if (!response.ok) {
        throw new Error(response.statusText);
      }
      firebaseToken = await response.text();
    } catch (error) {
      console.error("Error creating firebase custom token:", error.message);
      return;
    }
    try {
      const userCredential = await signInWithCustomToken(
        getAuth(),
        firebaseToken
      );
      const { claims } = await userCredential.user.getIdTokenResult(false);
      if (claims.immersNewUser) {
        // first time visit from a user from another immer
        window.plausible("Sign Up", {
          props: { method: `Immers Space: ${profile.homeImmer}` },
        });
      } else if (claims.ssoNewUser) {
        // new registration via custom OIDC/SAML provider
        window.plausible("Sign Up", {
          props: { method: `Custom SSO: ${immersClient.sessionInfo.provider}` },
        });
      } else {
        this.trackReturningLogin(
          immersClient.sessionInfo.provider
            ? `Custom SSO: ${immersClient.sessionInfo.provider}`
            : `Immers Space: ${profile.homeImmer}`,
          userCredential.user.uid
        );
      }
      // pull in latest profile updates
      syncProfileToFrame(userCredential.user.uid);
      return true;
    } catch (error) {
      console.error(
        "Error logging in with firebase custom token: ",
        error.message
      );
    }
  },

  //Create a user entry in the database
  // (Not auth user!)
  async createUser(user) {
    //Make new user data

    await setDoc(doc(database, "users", user.uid), {
      email: user.email,
      createdTime: Timestamp.now(),
      lastLogin: Timestamp.now(),
      connectionsUsernames: {},
      isTutorialActive: true,
      isChatSupportActive: true,
      arrowKeysTurnUser: true,
      avatarOptimizationOverrideEnabled: false,
      cameraMode: CameraMode.FirstPerson,
      cameraRecenterMode: CameraRecenterMode.AvatarToCamera,
      clickToMove: true,
      nametag: stateManager.getState().avatar.nametag,
      api: { key: uuidv4(), timestamp: Timestamp.now() },
      prefersLotus: false,
    });

    this.createNewDefaultInventory(user.uid);
    const data = { email: user.email };
    this.sendToSendInBlue(data);
  },

  resetPassword: function (email) {
    const auth = getAuth();
    sendPasswordResetEmail(auth, email).then(() => {
      console.debug("Sent password reset email.");
    });
  },

  sendVerificationEmail: function () {
    const auth = getAuth();
    sendEmailVerification(auth.currentUser);
  },

  sendToSendInBlue: function (data) {
    if (branding.type !== "mainline") {
      return;
    }

    const options = {
      method: "POST",
      headers: {
        accept: "application/json",
        "content-type": "application/json",
      },
      body: JSON.stringify({ email: data.email, listIds: [3] }),
    };
    fetch(stateManager.getState().apiURL + "/sendinblue", options)
      .then(async (response) => {
        if (!response.ok) {
          throw new Error(await response.text());
        }
        return response.json();
      })
      .then((response) => console.log(response))
      .catch((err) =>
        console.error(
          "There was an error adding your email to subscribers:",
          err
        )
      );
  },

  createNewDefaultInventory(uid) {
    addDoc(collection(database, "users", uid, "inventoryspheres"), {
      type: "sphere",
      name: "Paris",
      sphereURL: defaultAsset_PhotoSphere2,
      public_id: "none",
      fromInventory: true,
      prestocked: true,
    });

    addDoc(collection(database, "users", uid, "inventoryspheres"), {
      type: "sphere",
      name: "Outdoors",
      sphereURL: defaultAsset_PhotoSphere1,
      public_id: "none",
      fromInventory: true,
      prestocked: true,
    });

    addDoc(collection(database, "users", uid, "inventoryimages"), {
      type: "image",
      name: "Frame Image",
      public_id: "none",
      imageURL: defaultAsset_Image,
      height: 1275,
      width: 1650,
      fromInventory: true,
      prestocked: true,
    });

    addDoc(collection(database, "users", uid, "inventorypdfs"), {
      type: "pdf",
      name: "Remote Work Playbook",
      public_id: "none",
      pdfURL: `${CLOUDINARY_FRAME_CDN_URL_HTTPS}/image/upload/v1581459797/remoteworkplaybook_p1pye8.pdf`,
      height: 792,
      pages: 6,
      width: 612,
      fromInventory: true,
      prestocked: true,
    });

    addDoc(collection(database, "users", uid, "inventoryvideos"), {
      type: "video",
      videoName: "Welcome to Frame",
      public_id: "none",
      duration: 143,
      videoURL: `${CLOUDINARY_FRAME_CDN_URL_HTTPS}/video/upload/v1581469498/In_World_UI_Menu_Frame_wrodp8.mp4`,
      videoHLSURL: `${CLOUDINARY_FRAME_CDN_URL_HTTPS}/video/upload/f_m3u8/sp_full_hd_lean/v1613702533/dtqgeMaXgnc3cR88hBvcI6qgSSm2/babylon-mediasoup/inventoryvideos/prj9khqt9olxwzuzqm5d.m3u8`,
      videoMPDURL: `${CLOUDINARY_FRAME_CDN_URL_HTTPS}/video/upload/f_mpd/sp_full_hd_lean/v1618936483/dtqgeMaXgnc3cR88hBvcI6qgSSm2/weekly/videos/rvlpugdqkiiwhm8ewavu.mpd`,
      height: 480,
      width: 854,
      fromInventory: true,
      prestocked: true,
      loaded: true,
      isStreamable: true,
    });
    addDoc(collection(database, "users", uid, "inventorymodels"), {
      type: "model",
      name: "Dog",
      modelURL: defaultAsset_Dog,
      fromInventory: true,
      sharedAtlas: "",
      prestocked: true,
    });
  },

  bindUserToState() {
    const auth = getAuth();
    onAuthStateChanged(auth, async (user) => {
      console.debug("Authentication:", user);
      let loggedIn;
      if (user) {
        const token = await user.getIdTokenResult();
        const isProviderLogin =
          token?.signInProvider && token?.signInProvider !== "password";

        UserStore.setState({ userAuthObject: user });
        setupPrivateChats(user.uid);

        if (
          !user.email &&
          token?.signInProvider !== "custom" &&
          token?.signInProvider !== "microsoft.com"
        ) {
          const providerText = token?.signInProvider || "Your login";
          stateManager.getState().addNotification({
            duration: 10000,
            text: `${providerText} did not provide a valid e-mail address. Please try another sign-in method`,
          });
        } else if (isProviderLogin || user.emailVerified) {
          // Federated identity logins don't always have emailVerified
          const isDeveloper =
            (user.email?.endsWith("@virbela.com") ||
              user.email?.endsWith("@framevr.io")) &&
            user.emailVerified;
          stateManager.setState({
            userID: user.uid,
            userLoggedIn: true,
            isDeveloper,
            email: user.email,
          });
          // save last logged in

          unsubProfile?.();
          const profileDocRef = doc(database, "users", user.uid);
          unsubProfile = onSnapshot(profileDocRef, (profileDoc) => {
            // logged in with no profile means new user
            if (!profileDoc.exists()) {
              this.createUser(user);
              // snapshot listener will be called again with the new profile data
              return;
            }

            const profile = profileDoc.data();

            if (profile.tombstone) {
              // users has been deleted server-side, terminate session
              return this.logout().then(() => {
                // not sure why unload would be needed between logout & reload; but preserving previous code
                this.unloadUserData();
                window.location.reload();
              });
            }

            const { frame, isConnected, disallowGuests } =
              stateManager.getState();
            const { permissions, stateOverrides } = updateUserPermissions(
              auth,
              frame,
              isConnected,
              profile.isGlobalAdmin,
              disallowGuests
            );
            const stateUpdate = {
              userBound: true,
              api: profile.api || {
                key: null,
                timestamp: null,
              },
              // dont turn off if was on before, but turn on if tutorial active
              isChatSupportActive:
                profile.isTutorialActive &&
                stateManager.getState().frameOwnerPermission
                  ? true
                  : stateManager.getState().isChatSupportActive,
              connectionsUsername:
                profile.connectionsUsernames?.[webappCredentials.immers.server],
              ...permissions,
              ...stateOverrides,
            };
            for (const [profileProp, stateProp] of Object.entries(
              PROFILE_STATE_PROPS
            )) {
              // don't set if undefined so that defaults remain in place
              if (profile[profileProp] !== undefined) {
                stateUpdate[stateProp] = profile[profileProp];
              }
            }
            const avatarUpdate = {
              email: user.email,
              isGuest: false,
            };
            for (const [profileProp, avatarProp] of Object.entries(
              PROFILE_AVATAR_PROPS
            )) {
              // don't set if undefined so that defaults remain in place
              if (profile[profileProp] !== undefined) {
                avatarUpdate[avatarProp] = profile[profileProp];
              }
            }
            if (profile.profilePhoto?.profilePhotoURL) {
              avatarUpdate.photo = getUpdatedCloudinaryUrl(
                cloudinaryStringSlice(
                  profile.profilePhoto.profilePhotoURL,
                  PROFILE_PHOTO_OPTIMIZATIONS
                )
              );
            }
            updateStateProfileFeatures(profile);

            // avoid recreating 3d avatar if not changed
            if (
              profile.avatar &&
              !equal(profile.avatar, stateManager.getState().facade)
            ) {
              setFacade(profile.avatar);
            }
            stateManager.setState(stateUpdate);

            const isStaff = stateManager.getState().isStaff();
            avatarUpdate.isStaff = isStaff;
            if (!equal(avatarUpdate, previousAvatarUpdate)) {
              setAvatar(avatarUpdate);
              previousAvatarUpdate = avatarUpdate;
            }

            user.createdTime =
              profile.createdTime?.toDate().getTime() ?? Timestamp.now();

            //set user state (#2359) on subscribed changes
            UserStore.setState({
              user: new User({
                ...user,
                dismissedIntroTutorial: profile.dismissedIntroTutorial,
                ...stateUpdate,
              }),
            });

            //load user's frame info into state
            this.loadCurrentUserFrames();

            //load "frames im a member of"
            this.loadMemberFrames();

            //load "frames im an admin of"
            this.loadUserAdminFrames();
          });
          loggedIn = true;
        }
      } else {
        disconnectPrivateChats();
        UserStore.setState({ userAuthObject: null });
      }
      if (!loggedIn) {
        // if we want to support logging out without refreshing,
        // we'll need to reset all profile data in state here
        stateManager.setState({
          userLoggedIn: false,
          userBound: true,
          userEmail: "none",
          userID: "anonymous",
          userHomNavigationItems: [],
        });
      }

      let bannedFrames;
      try {
        bannedFrames = JSON.parse(localStorage?.getItem("bannedFrames")) || [];
      } catch (err) {
        console.error(
          "Cant parse json:",
          err,
          localStorage?.getItem("bannedFrames")
        );
      }

      if (bannedFrames.indexOf(stateManager.getState().frame.name) !== -1) {
        window.location.href = "/";
      }
    });
  },
  loadCurrentUserFrames() {
    const framesRef = query(
      collection(database, "spaces"),
      where("owner", "==", UserStore.getState().user.uid)
    );
    let frames = [];

    unsubUserFrames?.();
    unsubUserFrames = onSnapshot(framesRef, (querySnapshot) => {
      querySnapshot.docChanges().forEach(function (change) {
        if (change.type === "added") {
          frames.push(frameHydrate(change.doc.data()));
        }
        if (change.type === "removed") {
          frames = frames.filter(
            (el) => el.spaceID !== change.doc.data().spaceID
          );
        }
        if (change.type === "modified") {
          const index = frames.findIndex(
            (p) => p.spaceID === change.doc.data().spaceID
          );
          frames[index] = frameHydrate(change.doc.data());
        }
      });

      //set state (new user state)
      UserStore.setState({ userFrames: [...frames] });
    });
  },
  loadMemberFrames() {
    const framesRef = query(
      collection(database, "spaces"),
      where("members", "array-contains", {
        email: UserStore.getState().user.email,
        role: "member",
      })
    );
    let frames = [];

    unsubMemberFrames?.();
    unsubMemberFrames = onSnapshot(framesRef, (querySnapshot) => {
      querySnapshot.docChanges().forEach(function (change) {
        if (change.type === "added") {
          frames.push(frameHydrate(change.doc.data()));
        }
        if (change.type === "removed") {
          frames = frames.filter(
            (el) => el.spaceID !== change.doc.data().spaceID
          );
        }
        if (change.type === "modified") {
          const index = frames.findIndex(
            (p) => p.spaceID === change.doc.data().spaceID
          );
          frames[index] = frameHydrate(change.doc.data());
        }
      });

      //set state (new user state)
      UserStore.setState({ memberFrames: [...frames] });
    });
  },
  loadUserAdminFrames() {
    let adminFrames = [];
    const adminFramesQuery = query(
      collection(database, "spaces"),
      where("admins", "array-contains", {
        email: UserStore.getState().user.email,
        role: "admin",
      })
    );
    unsubUserAdminFrames?.();

    unsubUserAdminFrames = onSnapshot(adminFramesQuery, (querySnapshot) => {
      querySnapshot.docChanges().forEach(function (change) {
        if (change.type === "added") {
          adminFrames.push(frameHydrate(change.doc.data()));
        }
        if (change.type === "removed") {
          adminFrames = adminFrames.filter(
            (el) => el.spaceID !== change.doc.data().spaceID
          );
        }
        if (change.type === "modified") {
          const index = adminFrames.findIndex(
            (p) => p.spaceID === change.doc.data().spaceID
          );
          adminFrames[index] = frameHydrate(change.doc.data());
        }

        //set state
        UserStore.setState({ adminFrames: [...adminFrames] });
      });
    });
  },
  unloadUserData() {
    unsubProfile?.();
    unsubUserFrames?.();
  },

  pollForEmailVerified(interval, max) {
    let reloadTries = 0;
    const vm = this;

    return new Promise((resolve, reject) => {
      function pollAndRepeat() {
        if (vm.reloadInterval) {
          clearTimeout(vm.reloadInterval);
          vm.reloadInterval = null;
        }
        vm.reloadInterval = setTimeout(() => {
          if (reloadTries === max) {
            reject(
              new MaxUserReloads("Maximum number of user reloads reached")
            );
          } else if (UserStore.getState().userAuthObject?.emailVerified) {
            resolve();
          } else {
            reloadTries += 1;
            reload(UserStore.getState().userAuthObject);
            pollAndRepeat();
          }
        }, interval);
      }
      pollAndRepeat();
    });
  },

  /**
   * Update one or more of the user profile fields
   *
   * @param {string} userID the user to update
   * @param {Object} profileFields profileFields one or more fields of the userprofile to update
   * @param {string} [profileFields.nametag] Users name tag
   * @param {string} [profileFields.company] Company the user represents
   * @param {string} [profileFields.statusMessage] Status message to indicate activity
   * @param {string} [profileFields.linkedInURL] Hyperlink to users linkedin
   * @param {string} [profileFields.twitterURL] Hyperlink to users twitter
   * @param {Record<string, string>[]} [profileFields.apiKeys] Hyperlink to users twitter
   * @param {boolean} [profileFields.shareSensitiveInfoWithExternalAPICall] whether to allow nametag/email and other sensitive fields to be shared with interactivity rest api actions.
   */
  updateProfile(userID, profileFields) {
    const userRef = doc(database, "users", userID);
    updateDoc(userRef, profileFields);
  },

  async createOrRegenApiKey() {
    const userRef = doc(database, "users", UserStore.getState().user.uid);
    const key = uuidv4();
    // wait for write to commit to server so that api key is immediately usable on return
    await updateDoc(userRef, {
      api: { key, timestamp: serverTimestamp() },
    });
    return key;
  },

  async getUserIdByEmail(email) {
    if (!email) {
      return undefined;
    }
    const profileDocRef = query(
      collection(database, "users"),
      where("email", "==", email)
    );
    const userProfileDocs = await getDocs(profileDocRef);
    if (userProfileDocs.empty) {
      return undefined;
    } else {
      return userProfileDocs.docs[0].id;
    }
  },
  setDismissedIntroTutorial({ dismissedIntroTutorial }) {
    if (stateManager.getState().userLoggedIn) {
      const userRef = doc(database, "users", UserStore.getState().user.uid);
      updateDoc(userRef, { dismissedIntroTutorial });
    }
  },
  trackReturningLogin(method, uid) {
    window.plausible("Log In", {
      props: { method },
    });
    updateDoc(doc(database, "users", uid), {
      lastLogin: Timestamp.now(),
    }).catch((err) => {
      console.warn("Error updating lastLogin", err);
    });
  },
};

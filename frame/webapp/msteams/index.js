import state from "../core/state";
import {
  getAdditionalUserInfo,
  getAuth,
  updateEmail,
  signInWithCustomToken,
  // linkWithPopup
} from "firebase/auth";
import dbFrame from "../core/dbFrame";
import * as microsoftTeams from "@microsoft/teams-js";
import { updateUserSettings } from "../core/utils/User";

//Set api/signaling to development current
state.setState({
  apiURL: "https://api.dev.framevr.io",
  signalingURL: "wss://api.dev.framevr.io",
});

microsoftTeams.initialize();

var authTokenRequest = {
  successCallback: async function (token) {
    try {
      //Send token to api for verification and minting of firebase auth token
      const response = await fetch(
        state.getState().apiURL + "/auth/firebase/msteams",
        {
          body: JSON.stringify({ token }),
          headers: {
            "Content-Type": "application/json",
          },
          method: "post",
        }
      );

      let firebaseToken = await response.json();
      const auth = getAuth();
      const userCredential = await signInWithCustomToken(
        auth,
        firebaseToken.token
      ).catch(async (error) => {
        //This error means that accounts need to be joined in some way
        if (error.code != "auth/account-exists-with-different-credential") {
          throw error;
        }

        //Find the email associated with the token
        console.log("Firebase token:", firebaseToken);
        //let methods = await auth().fetchSignInMethodsForEmail(
        //  firebaseToken.email
        //);

        //Popup window with permissiosn to link
        // linkWithPopup(auth.currentUser, "google").then(result => {
        //   console.log(result);
        //   //const credential = authprovider.credentialFromResult(result)
        //   //const user = result.user
        // });
        //auth().currentUser.linkWithCredential(credential);
      });

      //Check email
      if (!userCredential.user.email) {
        console.log(
          "User email not found! Setting now to",
          firebaseToken.email
        );
        await updateEmail(userCredential.user, firebaseToken.email);
      }
      state.setState({ email: firebaseToken.email });

      if (getAdditionalUserInfo(userCredential).isNewUser) {
        window.plausible("Sign Up", {
          props: { method: "Teams" },
        });
      } else {
        window.plausible("Log In", {
          props: { method: "Teams" },
        });
        // sync MS profile updates to frame
      }
      await updateUserSettings(userCredential.user.uid, {
        nametag: firebaseToken.username,
      });
    } catch (error) {
      var errorCode = error.code;
      var errorMessage = error.message;
      console.error("Cant auth to firebase", errorCode, errorMessage);
    }

    //Get the context and load the frame
    microsoftTeams.getContext(initalizeFrame);
  },
  failureCallback: function (error) {
    console.log("Firebase token error:", error);
  },
};

//Use azure to login to firebase
microsoftTeams.authentication.getAuthToken(authTokenRequest);

async function initalizeFrame(context) {
  let channelName = (
    context["tid"] +
    context["teamName"] +
    context["channelName"]
  )
    .replace(/ /g, "")
    .toLowerCase();

  let disabledFeatures = new Array(
    "logout",
    "streamingscreen-screenshare",
    "settingsmenu-title",
    "notifications-slack"
  );
  if (context.hostClientType === "android") {
    disabledFeatures.push("connect");
  }

  if (context.hostClientType !== "web") {
    disabledFeatures.push("sketchfab");
  }

  //Set api/signaling to development current
  state.setState({
    disabledFeatures: disabledFeatures,
  });

  //Settings when installing
  if (context.frameContext === "settings") {
    //Set what URL will load in a given context
    // websiteUrl is for external links, that link out to framevr.io
    // contentUrl is for internal/native page loads
    microsoftTeams.settings.setSettings({
      contentUrl: `https://${window.location.host}/`,
    });

    //Create frame for this applications tab
    //Create frame may succeed or fail, but still suceeds.
    await dbFrame.createFrame(channelName, { spectatorModeEnabled: true });

    //Make a blocking overlay for the config screen. This is kind hacky... but works until we can make a vue component do it
    let configScreen = document.createElement("DIV");
    configScreen.setAttribute(
      "style",
      "position: absolute; display: flex; justify-content: center; align-items: center; font-family: 'Poppins', sans-serif; font-weight: 700; width: 100%; height: 100%; color: black; text-align: center; background-color: white; z-index: 21;"
    );
    configScreen.innerHTML =
      "Nice! Your Frame App for Microsoft Teams is all configued.";
    document.body.prepend(configScreen);

    microsoftTeams.settings.setValidityState(true); //Enable OK button
  } else {
    router.push(`/${channelName}`);
    //dbFrame.bindFrameToState(channelName);
  }

  //Hide loading screen
  document.querySelector("#loading-screen").style.display = "none";

  console.warn("MSTeamsContext:", context);
}

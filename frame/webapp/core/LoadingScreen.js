import { database } from "./database";
import { collection, query, where, getDocs } from "firebase/firestore";
import stateManager from "./state";
import frameLogo from "../stage/branding/logo.svg";
import branding from "./branding";
import { frameCapabilityValue, frameHydrate } from "@core/utils/Frame";

export const LoadingScreen = {
  setup: async () => {
    //Build loading screen
    //TODO: this should just be a div and let css carry the rest
    let loadingScreenDiv = document.createElement("DIV");
    loadingScreenDiv.setAttribute("id", "loading-screen");

    let frameLogoDiv = document.createElement("DIV");
    frameLogoDiv.setAttribute("class", "frame-logo");
    loadingScreenDiv.appendChild(frameLogoDiv);

    let loadingDiv = document.createElement("DIV");
    loadingDiv.setAttribute("class", "loading");
    loadingDiv.innerHTML = "LOADING...";
    frameLogoDiv.appendChild(loadingDiv);

    let preloadingDiv = document.createElement("DIV");
    preloadingDiv.setAttribute("id", "preloader");

    let loaderDiv = document.createElement("DIV");
    loaderDiv.setAttribute("class", "loader");

    preloadingDiv.appendChild(loaderDiv);

    frameLogoDiv.appendChild(preloadingDiv);

    let spinnerDiv = document.createElement("DIV");
    spinnerDiv.setAttribute("class", "spinner");
    let bounce1Div = document.createElement("DIV");
    bounce1Div.setAttribute("class", "bounce1");
    let bounce2Div = document.createElement("DIV");
    bounce2Div.setAttribute("class", "bounce2");
    let bounce3Div = document.createElement("DIV");
    bounce3Div.setAttribute("class", "bounce3");
    spinnerDiv.appendChild(bounce1Div);
    spinnerDiv.appendChild(bounce2Div);
    spinnerDiv.appendChild(bounce3Div);

    loadingScreenDiv.appendChild(spinnerDiv);

    let poweredbyDiv = document.createElement("DIV");
    poweredbyDiv.setAttribute("class", "poppins powered-by-frame-text");
    poweredbyDiv.setAttribute(
      "style",
      'font-size: 1rem !important; font-weight: 400 !important; letter-spacing: 3px !important; bottom: 32px !important; font-family: "Poppins", sans-serif !important;'
    );
    poweredbyDiv.innerHTML = "POWERED BY FRAMEVR.IO";
    // for when we try to get this to be a link
    // let poweredbyLink = document.createElement("A");
    // var linkText = document.createTextNode("FRAME");
    // poweredbyLink.appendChild(linkText);
    // poweredbyLink.title = "FRAME";
    // poweredbyLink.href = "https://learn.framevr.io";
    //poweredbyLink.setAttribute("target", "_blank");
    if (branding.type !== "full-whitelabel") {
      loadingScreenDiv.appendChild(poweredbyDiv);
    }

    document.body.appendChild(loadingScreenDiv);

    const frameQuery = query(
      collection(database, "spaces"),
      where(
        "spaceID",
        "==",
        new URL(window.location.href).pathname.replaceAll("/", "")
      )
    );
    const querySnapshot = await getDocs(frameQuery);
    querySnapshot.forEach((doc) => {
      spinnerDiv.style.display = "none";

      // technically we should query here to see if appSettings.subscriptionsEnabled true or false,
      // however stateManger subscriptionsEnabled is not yet loaded from the appSettings at the time this loading screen code runs
      // and i dont want to introduce another query just to read that setting.
      // frameTierId should only be set in the case of subscriptionsEnabled = true, and
      // isBrandable should only be set in the case of subscriptionsEnabled = false, ideally.
      // omitting any checks for subscriptionsEnabled here should be ok at this time since it would only cause an issue
      // if a whitelabel client had subscriptionsEnabled, someone upgraded their frame to pro, and then the whitelabel client switched subscriptionsEnabled=false.
      // since that scenario does not have the capability to exist as of yet, i'm omitting any check here for subscriptionsEnabled at this time
      const frame = frameHydrate(doc.data());

      if (
        frameLogoDiv &&
        (frame.isBrandable || frame.frameTierId >= 4) &&
        frameCapabilityValue(frame, "loadScreenImage")?.url
      ) {
        frameLogoDiv.style.backgroundImage =
          "url(" + frameCapabilityValue(frame, "loadScreenImage").url + ")";
      } else {
        frameLogoDiv.style.backgroundImage = "url('" + frameLogo + "')";
      }
      frameLogoDiv.style.display = "block";
      frameLogoDiv.style.visibility = "visible";
    });

    //Subscribe to changes in showing/hiding the load screen
    stateManager.subscribe(
      (state) => state.loadingScreen,
      (loadingScreen) => {
        if (loadingScreen) {
          loadingScreenDiv.style.display = "block";
        } else {
          loadingScreenDiv.style.display = "none";
        }
      },
      {
        fireImmediately: true,
      }
    );
  },
};

export const showFullPageError = (errorText) => {
  document.body.innerHTML = errorText;
  document.body.setAttribute(
    "style",
    "text-align:left;padding-top:1em;width:50%;margin-left:30%;margin-right:30%;margin-top:30%"
  );
  const loadingScreen = document.getElementById("loading-screen");
  loadingScreen && loadingScreen.remove();
  console.error(errorText);
  throw new Error(errorText);
};

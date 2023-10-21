import credentials from "../credentials.json";
import { initializeApp } from "firebase/app";
import { initializeFirestore } from "@firebase/firestore";

import {
  getAuth,
  createUserWithEmailAndPassword,
  sendEmailVerification,
  signInWithEmailAndPassword,
  GoogleAuthProvider,
  getAdditionalUserInfo,
  signInWithPopup,
  signInWithCustomToken,
  OAuthProvider,
  onAuthStateChanged,
  FacebookAuthProvider,
  sendPasswordResetEmail,
  updateEmail,
} from "firebase/auth";

//Construct firebase
const firebaseApp = initializeApp(credentials.firebase);
const db = initializeFirestore(firebaseApp, {
  experimentalForceLongPolling: true,
});
//Assign this a global variable, so other parts of the app can access it

export { db as database };
export { getAuth };
export { createUserWithEmailAndPassword };
export { sendEmailVerification };
export { signInWithEmailAndPassword };
export { GoogleAuthProvider };
export { getAdditionalUserInfo };
export { signInWithPopup };
export { signInWithCustomToken };
export { OAuthProvider };
export { onAuthStateChanged };
export { FacebookAuthProvider };
export { sendPasswordResetEmail };
export { updateEmail };

import { database } from "./database";
import {
  getDocs,
  updateDoc,
  orderBy,
  limit,
  collection,
  query,
  onSnapshot,
  Unsubscribe,
} from "firebase/firestore";
import stateManager from "./state";
let unsub: Unsubscribe;
import { setupDestinations } from "./dbDestinations";
import { AppSettings } from "./state-utils";
import { showFullPageError } from "./LoadingScreen";

export default {
  bindApplicationSettingsToState: function (): void {
    const globalSettingsQuery = query(
      collection(database, "appSettings"),
      orderBy("dateAdded", "desc"),
      limit(1)
    );
    unsub = onSnapshot(
      globalSettingsQuery,
      (settingsData) => {
        if (settingsData.empty) {
          console.error("No global settings for this webapp.");
          showFullPageError(
            "Your browser had trouble connecting to Frame. Make sure you're on the latest version of your browser and refresh to try again. <br> <br> If you're still having issues, try in a private browser window. If it works there, one of your browser extensions might be responsible. <br> <br> If you're still having issues, email support@framevr.io"
          );
          stateManager.setState({
            creatorDomains: [],
            homeFrame: undefined,
            homeRedirect: undefined,
          });
        } else {
          //Can we drop the foreach here?
          settingsData.forEach(async function (settingsDoc) {
            const stateSettings = settingsDoc.data() as AppSettings;
            const { announcement, staffAnnouncement } = stateSettings;
            const state = stateManager.getState();

            if (announcement) {
              state.addNotification({
                dismissable: true,
                text: announcement,
              });
            }
            if (staffAnnouncement && state.isStaff()) {
              state.addNotification({
                dismissable: true,
                text: staffAnnouncement,
              });
            }

            // announcement is ephemeral. No need to keep in the state
            delete (stateSettings as any).announcement;
            delete (stateSettings as any).StaffAnnouncement;
            delete (stateSettings as any).dateAdded; //Remove date settings were created
            stateManager.setState({
              ...stateSettings,
              appSettingsID: settingsDoc.id,
              appSettingsBound: true,
            });
            setupDestinations(settingsDoc.ref.path, true);
          });
        }
      },
      (error) => {
        console.error("Error getting global settings:", error);
        showFullPageError(
          "Your browser had trouble connecting to Frame. Make sure you're on the latest version of your browser and refresh to try again. <br> <br> If you're still having issues, try in a private browser window. If it works there, one of your browser extensions might be responsible. <br> <br> If you're still having issues, email support@framevr.io"
        );
      }
    );
  },

  unsubFromListener: function (): void {
    unsub();
  },
};

export const sendGlobalAnnouncement = async (
  announcement: string,
  staffOnly = false
): Promise<void> => {
  const ref = await getAppSettingsRef();
  if (!ref) {
    console.error(`Announcement couldn't be sent. appSettings is missing.`);
    return;
  }

  updateDoc(
    ref,
    staffOnly ? { staffAnnouncement: announcement } : { announcement }
  ).then(() => {
    // Remove announcement from appSettings immediately.
    setTimeout(() => {
      updateDoc(
        ref,
        staffOnly ? { staffAnnouncement: null } : { announcement: null }
      );
    }, 10000);
  });
};

export const updateAppSettings = async (data: AppSettings): Promise<void> => {
  const ref = await getAppSettingsRef();
  if (!ref) {
    console.error(`appSettings is missing and could be updated.`);
    return;
  }

  updateDoc(ref, { ...data }).catch((err) => {
    console.error(`Error while updating appSettings:`, err);
  });
};

const getAppSettingsRef = async () => {
  const appSettingsQuery = query(
    collection(database, "appSettings"),
    orderBy("dateAdded", "desc")
  );

  const snapshot = await getDocs(appSettingsQuery);
  if (snapshot.empty) {
    return null;
  }
  return snapshot.docs[0].ref;
};

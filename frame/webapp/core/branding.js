//Branding image and text references
const branding = {
  type: "mainline",
  homeFrame: undefined,
  homeRedirect: "https://learn.framevr.io",
  outLink: "https://dev.framevr.io",
  favIcon: "stage/branding/favicon.ico",
  metaImage: "https://dev.framevr.io/assets/meta-image.png",
  name: "Frame",
  description:
    "Immersive presentations and meetings - right from the browser on desktop, mobile, and VR",
  shortDescription:
    "FRAME is a space for immersive presentations and meetings - right from a browser",
  termsOfService: "https://learn.framevr.io/tos-privacy-policy",
  support: "hello@framevr.io",
};
//TODO: with webpack-html-plugin update we could make metaImage a real path like favicon.
//      Importing in core/index.js until then i guess...
module.exports = branding;

import state from "../core/state";

// Load Library Theme css (inherits from Frame Whitelabel theme)
import "./main.scss";

//Set api/signaling to development current
state.setState({
  apiURL: "https://doabackflip.com",
  signalingURL: "wss://abackflip.io",
});

cordova.define('cordova/plugin_list', function(require, exports, module) {
  module.exports = [
    {
      "id": "cordova-plugin-ble-central.ble",
      "file": "plugins/cordova-plugin-ble-central/www/ble.js",
      "pluginId": "cordova-plugin-ble-central",
      "clobbers": [
        "ble"
      ]
    },
    {
      "id": "cordova-plugin-wkwebview-engine.ios-wkwebview-exec",
      "file": "plugins/cordova-plugin-wkwebview-engine/src/www/ios/ios-wkwebview-exec.js",
      "pluginId": "cordova-plugin-wkwebview-engine",
      "clobbers": [
        "cordova.exec"
      ]
    },
    {
      "id": "cordova-plugin-wkwebview-engine.ios-wkwebview",
      "file": "plugins/cordova-plugin-wkwebview-engine/src/www/ios/ios-wkwebview.js",
      "pluginId": "cordova-plugin-wkwebview-engine",
      "clobbers": [
        "window.WkWebView"
      ]
    },
    {
      "id": "cordova-plugin-chrome-apps-common.events",
      "file": "plugins/cordova-plugin-chrome-apps-common/events.js",
      "pluginId": "cordova-plugin-chrome-apps-common",
      "clobbers": [
        "chrome.Event"
      ]
    },
    {
      "id": "cordova-plugin-chrome-apps-common.errors",
      "file": "plugins/cordova-plugin-chrome-apps-common/errors.js",
      "pluginId": "cordova-plugin-chrome-apps-common"
    },
    {
      "id": "cordova-plugin-chrome-apps-common.stubs",
      "file": "plugins/cordova-plugin-chrome-apps-common/stubs.js",
      "pluginId": "cordova-plugin-chrome-apps-common"
    },
    {
      "id": "cordova-plugin-chrome-apps-common.helpers",
      "file": "plugins/cordova-plugin-chrome-apps-common/helpers.js",
      "pluginId": "cordova-plugin-chrome-apps-common"
    },
    {
      "id": "cordova-plugin-chrome-apps-sockets-udp.sockets.udp",
      "file": "plugins/cordova-plugin-chrome-apps-sockets-udp/sockets.udp.js",
      "pluginId": "cordova-plugin-chrome-apps-sockets-udp",
      "clobbers": [
        "chrome.sockets.udp"
      ]
    }
  ];
  module.exports.metadata = {
    "cordova-plugin-compat": "1.2.0",
    "cordova-plugin-ble-central": "1.2.2",
    "cordova-plugin-wkwebview-engine": "1.1.4",
    "cordova-plugin-whitelist": "1.3.3",
    "cordova-plugin-chrome-apps-common": "1.0.7",
    "cordova-plugin-chrome-apps-iossocketscommon": "1.0.2",
    "cordova-plugin-chrome-apps-sockets-udp": "1.3.0"
  };
});
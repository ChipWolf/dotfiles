// ~/.finicky.js

export default {
  defaultBrowser: "Google Chrome:chipwolf.uk",

  options: {
    checkForUpdates: true,
    logRequests: true,
  },

  handlers: [
    {
      match: ["on-running.com/*", "*.on-running.com/*"],
      browser: "Google Chrome:on-running.com",
    },
    {
      match: ["*.atlassian.net/*", "atlassian.com/*", "*.atlassian.com/*"],
      browser: "Google Chrome:on-running.com",
    },
    {
      match: "github.com/*",
      browser: "Google Chrome:on-running.com",
    },
    {
      match: ["google.com/*", "*.google.com/*"],
      browser: "Google Chrome:on-running.com",
    },
    {
      match: ["okta.com/*", "*.okta.com/*"],
      browser: "Google Chrome:on-running.com",
    },
  ],
};


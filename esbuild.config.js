const build = require("./config/esbuild.defaults.js");

const esbuildOptions = {
  globOptions: {
    excludeFilter: /\.(dsd\.css|dsd\.js)$/,
  },
};

build(esbuildOptions);

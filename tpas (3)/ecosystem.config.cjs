// PM2 ecosystem config
module.exports = {
  apps: [
    {
      name: "express-ts-api",
      script: "dist/server.js",
      instances: "max",
      exec_mode: "cluster",
      watch: false,
      env: {
        NODE_ENV: "production",
      },
    },
  ],
};

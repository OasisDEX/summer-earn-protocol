import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox"
import "@nomicfoundation/hardhat-foundry";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.26",
    settings: {
      viaIR: true,
    },
  },
  paths: {
    sources: "./src",
  },
};

export default config;

import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 100000
          }
        }
      }
    ]
  },
  networks: {
    hardhat: {},
  }
};

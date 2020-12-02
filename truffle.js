var HDWalletProvider = require("@truffle/hdwallet-provider");
var mnemonic = "menu task lady modify afford join error frost cement into enact coconut";

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider({
          mnemonic: {
            phrase: mnemonic
          },
          providerOrUrl: "http://127.0.0.1:8545/",
          numberOfAddresses: 50
        });
      },
      network_id: '*'
    },
    develop: {
      port: 8545,
      network_id: '*',
      accounts: 50
    }
  },
  compilers: {
    solc: {
      version: "^0.6.0"
    }
  }
};
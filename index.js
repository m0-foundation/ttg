const IERC20PricelessAuction = require("./out/IERC20PricelessAuction.sol/IERC20PricelessAuction.json");
const IList = require("./out/IList.sol/IList.json");
const ISPOG = require("./out/ISPOG.sol/ISPOG.json");
const ISPOGGovernor = require("./out/ISPOGGovernor.sol/ISPOGGovernor.json");
const IValueToken = require("./out/IValueToken.sol/IValueToken.json");
const IVault = require("./out/IVault.sol/IVault.json");
const IVoteToken = require("./out/IVoteToken.sol/IVoteToken.json");

module.exports = {
  IERC20PricelessAuction: IERC20PricelessAuction.abi,
  IList: IList.abi,
  ISPOG: ISPOG.abi,
  ISPOGGovernor: ISPOGGovernor.abi,
  IValueToken: IValueToken.abi,
  IVault: IVault.abi,
  IVoteToken: IVoteToken.abi,
};

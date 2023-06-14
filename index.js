const IERC20 = require("./out/IERC20.sol/IERC20.json");
const IERC20PricelessAuction = require("./out/IERC20PricelessAuction.sol/IERC20PricelessAuction.json");
const IList = require("./out/IList.sol/IList.json");
const ISPOG = require("./out/ISPOG.sol/ISPOG.json");
const ISPOGGovernor = require("./out/ISPOGGovernor.sol/ISPOGGovernor.json");
const IValueToken = require("./out/IValueToken.sol/IValueToken.json");
const ISPOGVault = require("./out/ISPOGVault.sol/ISPOGVault.json");
const IVoteToken = require("./out/IVoteToken.sol/IVoteToken.json");
const IVoteVault = require("./out/IVoteVault.sol/IVoteVault.json");

module.exports = {
  IERC20: IERC20.abi,
  IERC20PricelessAuction: IERC20PricelessAuction.abi,
  IList: IList.abi,
  ISPOG: ISPOG.abi,
  ISPOGGovernor: ISPOGGovernor.abi,
  IValueToken: IValueToken.abi,
  ISPOGVault: ISPOGVault.abi,
  IVoteToken: IVoteToken.abi,
  IVoteVault: IVoteVault.abi,
};

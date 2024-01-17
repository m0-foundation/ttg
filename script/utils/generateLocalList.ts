import {
  generateContractList,
  rootFolder,
  writeList,
} from "../helpers/generateContractList";

writeList(
  generateContractList(
    `${rootFolder}/broadcast/Deploy.s.sol/31337`,
    "TTG - Local Testnet",
  ),
  "deployments/local",
  "contracts",
);

import {
  generateContractList,
  rootFolder,
  writeList,
} from "../helpers/generateContractList";

writeList(
  generateContractList(
    `${rootFolder}/broadcast/Deploy.s.sol/11155111`,
    "TTG - Sepolia Testnet",
  ),
  "deployments/sepolia",
  "contracts",
);

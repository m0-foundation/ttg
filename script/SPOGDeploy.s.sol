// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IVALUE, IVOTE } from "../src/tokens/ITokens.sol";
import { IDualGovernor } from "../src/governor/IDualGovernor.sol";

import { GovernanceDeployer } from "../src/deployer/GovernanceDeployer.sol";
import { GovernorDeployer } from "../src/deployer/GovernorDeployer.sol";
import { VoteDeployer } from "../src/deployer/VoteDeployer.sol";
import { Comptroller } from "../src/comptroller/Comptroller.sol";
import { Vault } from "../src/vault/Vault.sol";
import { VALUE } from "../src/tokens/VALUE.sol";
import { Auction } from "../src/auction/Auction.sol";

import { console, ERC20Mock } from "./ImportedContracts.sol";
import { BaseScript } from "./shared/Base.s.sol";

contract SPOGDeployScript is BaseScript {
    uint256 public constant DEPLOYER_STARTING_NONCE = 0;

    address public governanceDeployer;
    address public governor;
    address public comptroller;

    uint256 public voteQuorum = 65; // 65%
    uint256 public valueQuorum = 65; // 65%
    address public cash;
    uint256 public tax = 5e18;
    uint256 public taxLowerBound = 0;
    uint256 public taxUpperBound = 6e18;
    uint256 public inflator = 20; // 20%
    uint256 public fixedReward = 100 * 10e18;

    address public vote;
    address public value;
    address public vault;
    address public auction;

    function setUp() public override {
        super.setUp();
    }

    function run() public {
        vm.startBroadcast(deployer);

        address expectedComptroller = _getContractFrom(deployer, DEPLOYER_STARTING_NONCE + 7);

        address expectedGovernanceDeployer = _getContractFrom(deployer, DEPLOYER_STARTING_NONCE + 6);

        value = address(new VALUE("Comptroller Value", "VALUE", expectedComptroller));
        vault = address(new Vault(value));
        cash = address(new ERC20Mock("CashToken", "CASH", msg.sender, 100e18));
        auction = address(new Auction());

        address governorDeployer = address(new GovernorDeployer(expectedGovernanceDeployer));
        address voteDeployer = address(new VoteDeployer(expectedGovernanceDeployer));

        governanceDeployer = address(new GovernanceDeployer(expectedComptroller, governorDeployer, voteDeployer));

        Comptroller.Configuration memory config = Comptroller.Configuration(
            governanceDeployer,
            value,
            vault,
            cash,
            tax,
            taxLowerBound,
            taxUpperBound,
            inflator,
            fixedReward,
            voteQuorum,
            valueQuorum
        );

        comptroller = address(new Comptroller(config)); // 0x29b2440db4A256B0c1E6d3B4CDcaA68E2440A08f

        console.log("VALUE token address: ", value);
        console.log("Vault address: ", vault);
        console.log("Cash address: ", cash);
        console.log("Auction address: ", auction);
        console.log("Deployer address: ", governanceDeployer);
        console.log("Comptroller address: ", comptroller);
        console.log("DualGovernor address: ", governor = Comptroller(comptroller).governor());
        console.log("VOTE token address: ", vote = IDualGovernor(governor).vote());

        vm.stopBroadcast();
    }

    function _getContractFrom(address account, uint256 nonce) internal pure returns (address) {
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            nonce == 0x00
                                ? abi.encodePacked(bytes1(0xd6), bytes1(0x94), account, bytes1(0x80))
                                : nonce <= 0x7f
                                ? abi.encodePacked(bytes1(0xd6), bytes1(0x94), account, uint8(nonce))
                                : nonce <= 0xff
                                ? abi.encodePacked(bytes1(0xd7), bytes1(0x94), account, bytes1(0x81), uint8(nonce))
                                : nonce <= 0xffff
                                ? abi.encodePacked(bytes1(0xd8), bytes1(0x94), account, bytes1(0x82), uint16(nonce))
                                : nonce <= 0xffffff
                                ? abi.encodePacked(bytes1(0xd9), bytes1(0x94), account, bytes1(0x83), uint24(nonce))
                                : abi.encodePacked(bytes1(0xda), bytes1(0x94), account, bytes1(0x84), uint32(nonce))
                        )
                    )
                )
            );
    }
}

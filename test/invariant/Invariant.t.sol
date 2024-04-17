// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { console2 } from "../../lib/forge-std/src/Test.sol";
import { DeployBase } from "../../script/DeployBase.sol";

import { IEmergencyGovernor } from "../../src/interfaces/IEmergencyGovernor.sol";
import { IPowerToken } from "../../src/interfaces/IPowerToken.sol";
import { IRegistrar } from "../../src/interfaces/IRegistrar.sol";
import { IStandardGovernor } from "../../src/interfaces/IStandardGovernor.sol";
import { IZeroGovernor } from "../../src/interfaces/IZeroGovernor.sol";
import { IZeroToken } from "../../src/interfaces/IZeroToken.sol";
import { IDistributionVault } from "../../src/interfaces/IDistributionVault.sol";

import { ERC20ExtendedHarness } from "../utils/ERC20ExtendedHarness.sol";
import { TestUtils } from "../utils/TestUtils.sol";

import { TTGHandler } from "./handlers/TTGHandler.sol";

import { HolderStore } from "./stores/HolderStore.sol";
import { ProposalStore } from "./stores/ProposalStore.sol";
import { TimestampStore } from "./stores/TimestampStore.sol";

contract InvariantTests is TestUtils {
    TTGHandler internal _handler;

    HolderStore internal _holderStore;
    ProposalStore internal _proposalStore;
    TimestampStore internal _timestampStore;

    IRegistrar internal _registrar;

    IPowerToken internal _powerToken;
    IZeroToken internal _zeroToken;

    IEmergencyGovernor internal _emergencyGovernor;
    IStandardGovernor internal _standardGovernor;
    IZeroGovernor internal _zeroGovernor;

    IDistributionVault internal _vault;

    ERC20ExtendedHarness internal _cashToken1 = new ERC20ExtendedHarness("Cash Token 1", "CASH1", 18);
    ERC20ExtendedHarness internal _cashToken2 = new ERC20ExtendedHarness("Cash Token 1", "CASH2", 6);

    address[] internal _allowedCashTokens = [address(_cashToken1), address(_cashToken2)];

    uint256 internal _standardProposalFee = 1e18;

    DeployBase internal _deploy;

    modifier useCurrentTimestamp() {
        vm.warp(_timestampStore.currentTimestamp());
        _;
    }

    function setUp() external {
        _deploy = new DeployBase();
        _holderStore = new HolderStore();
        _timestampStore = new TimestampStore();

        _holderStore.initActors();

        address[][2] memory initialAccounts_ = [_holderStore.powerHolders(), _holderStore.zeroHolders()];
        uint256[][2] memory initialBalances_ = [_holderStore.powerHolderBalances(), _holderStore.zeroHolderBalances()];

        // NOTE: Using `DeployBase` as a contract instead of a script, means that the deployer is `_deploy` itself.
        address registrar_ = _deploy.deploy(
            address(_deploy),
            1,
            initialAccounts_,
            initialBalances_,
            _standardProposalFee,
            _allowedCashTokens
        );

        _registrar = IRegistrar(registrar_);

        _powerToken = IPowerToken(_registrar.powerToken());
        _zeroToken = IZeroToken(_registrar.zeroToken());

        _emergencyGovernor = IEmergencyGovernor(_registrar.emergencyGovernor());
        _standardGovernor = IStandardGovernor(_registrar.standardGovernor());
        _zeroGovernor = IZeroGovernor(_registrar.zeroGovernor());

        _proposalStore = new ProposalStore(_registrar, _emergencyGovernor, _standardGovernor, _zeroGovernor);

        _vault = IDistributionVault(_standardGovernor.vault());

        uint256 cashToken1MaxAmount_ = type(uint256).max / _holderStore.ZERO_HOLDER_NUM();

        for (uint256 i; i < _holderStore.ZERO_HOLDER_NUM(); i++) {
            address account_ = initialAccounts_[1][i];
            _cashToken1.mint(account_, cashToken1MaxAmount_);

            vm.prank(account_);
            _cashToken1.approve(address(_standardGovernor), cashToken1MaxAmount_);

            vm.prank(account_);
            _cashToken1.approve(address(_powerToken), cashToken1MaxAmount_);
        }

        _handler = new TTGHandler(_emergencyGovernor, _powerToken, _holderStore, _proposalStore, _timestampStore);

        // Set fuzzer to only call the handler
        targetContract(address(_handler));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = TTGHandler.emergencyGovernorAddToList.selector;
        selectors[1] = TTGHandler.voteOnEmergencyGovernorProposal.selector;
        selectors[2] = TTGHandler.executeEmergencyGovernorProposal.selector;

        targetSelector(FuzzSelector({ addr: address(_handler), selectors: selectors }));

        // Prevent these contracts from being fuzzed as `msg.sender`.
        excludeSender(address(_deploy));
        excludeSender(address(_handler));
        excludeSender(address(_powerToken));
        excludeSender(address(_zeroToken));
        excludeSender(address(_emergencyGovernor));
        excludeSender(address(_standardGovernor));
        excludeSender(address(_zeroGovernor));
        excludeSender(address(_registrar));
        excludeSender(address(_vault));
    }

    function invariant_main() public useCurrentTimestamp {
        uint256 totalSupply_;
        uint256 totalVotes_;

        for (uint256 i; i < _holderStore.POWER_HOLDER_NUM(); i++) {
            totalSupply_ += _powerToken.balanceOf(_holderStore.powerHolders()[i]);
        }

        for (uint256 i; i < _holderStore.POWER_HOLDER_NUM(); i++) {
            totalVotes_ += _powerToken.getVotes(_holderStore.powerHolders()[i]);
        }

        // Skip test if POWER total supply and/or voting power are zero.
        vm.assume(totalVotes_ != 0);
        vm.assume(_powerToken.totalSupply() != 0);

        assertGe(
            _powerToken.totalSupply(),
            totalSupply_,
            "POWER token totalSupply() should be greater than or equal to the sum of POWER token balanceOf()"
        );

        assertGe(
            _powerToken.totalSupply(),
            totalVotes_,
            "POWER token totalSupply() should be greater than or equal to the sum of POWER token getVotes()"
        );

        assertEq(
            totalSupply_,
            totalVotes_,
            "The sum of POWER token balanceOf() should be equal to the sum of POWER token getVotes()"
        );
    }
}

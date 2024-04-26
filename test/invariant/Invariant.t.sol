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

import { EmergencyGovernorDeployer } from "../../src/EmergencyGovernorDeployer.sol";
import { StandardGovernorDeployer } from "../../src/StandardGovernorDeployer.sol";

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

    EmergencyGovernorDeployer internal _emergencyGovernorDeployer;
    StandardGovernorDeployer internal _standardGovernorDeployer;

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

        // _emergencyGovernorDeployer_ = EmergencyGovernorDeployer(getExpectedEmergencyGovernorDeployer(address(this), 1));
        // _standardGovernorDeployer_ = StandardGovernorDeployer(getExpectedStandardGovernorDeployer(address(this), 1));

        _registrar = IRegistrar(registrar_);

        _powerToken = IPowerToken(_registrar.powerToken());
        _zeroToken = IZeroToken(_registrar.zeroToken());

        _emergencyGovernor = IEmergencyGovernor(_registrar.emergencyGovernor());
        _standardGovernor = IStandardGovernor(_registrar.standardGovernor());
        _zeroGovernor = IZeroGovernor(_registrar.zeroGovernor());

        _proposalStore = new ProposalStore(
            _registrar,
            _emergencyGovernor,
            _standardGovernor,
            _zeroGovernor,
            _allowedCashTokens
        );

        _vault = IDistributionVault(_standardGovernor.vault());

        _handler = new TTGHandler(_emergencyGovernor, _powerToken, _holderStore, _proposalStore, _timestampStore);

        // Set fuzzer to only call the handler
        targetContract(address(_handler));

        // bytes4[] memory selectors = new bytes4[](21);
        // selectors[0] = TTGHandler.emergencyGovernorAddToList.selector;
        // selectors[1] = TTGHandler.emergencyGovernorRemoveFromList.selector;
        // selectors[2] = TTGHandler.emergencyGovernorRemoveFromAndAddToList.selector;
        // selectors[3] = TTGHandler.emergencyGovernorSetKey.selector;
        // selectors[4] = TTGHandler.emergencyGovernorSetStandardProposalFee.selector;
        // selectors[5] = TTGHandler.voteOnEmergencyGovernorProposal.selector;
        // selectors[6] = TTGHandler.executeEmergencyGovernorProposal.selector;
        // selectors[7] = TTGHandler.standardGovernorAddToList.selector;
        // selectors[8] = TTGHandler.standardGovernorRemoveFromList.selector;
        // selectors[9] = TTGHandler.standardGovernorRemoveFromAndAddToList.selector;
        // selectors[10] = TTGHandler.standardGovernorSetKey.selector;
        // selectors[11] = TTGHandler.standardGovernorSetProposalFee.selector;
        // selectors[12] = TTGHandler.voteOnAllStandardGovernorProposals.selector;
        // selectors[13] = TTGHandler.executeAllStandardGovernorProposals.selector;
        // selectors[14] = TTGHandler.zeroGovernorResetToPowerHolders.selector;
        // selectors[15] = TTGHandler.zeroGovernorResetToZeroHolders.selector;
        // selectors[16] = TTGHandler.zeroGovernorSetCashToken.selector;
        // selectors[17] = TTGHandler.zeroGovernorSetEmergencyProposalThresholdRatio.selector;
        // selectors[18] = TTGHandler.zeroGovernorSetZeroProposalThresholdRatio.selector;
        // selectors[19] = TTGHandler.voteOnZeroGovernorProposal.selector;
        // selectors[20] = TTGHandler.executeZeroGovernorProposal.selector;

        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = TTGHandler.standardGovernorAddToList.selector;
        selectors[1] = TTGHandler.standardGovernorRemoveFromList.selector;
        selectors[2] = TTGHandler.standardGovernorRemoveFromAndAddToList.selector;
        selectors[3] = TTGHandler.standardGovernorSetKey.selector;
        selectors[4] = TTGHandler.standardGovernorSetProposalFee.selector;
        selectors[5] = TTGHandler.voteOnAllStandardGovernorProposals.selector;
        selectors[6] = TTGHandler.executeAllStandardGovernorProposals.selector;

        targetSelector(FuzzSelector({ addr: address(_handler), selectors: selectors }));

        // Prevent these contracts from being fuzzed as `msg.sender`.
        excludeSender(address(_deploy));
        excludeSender(address(_handler));
        excludeSender(address(_proposalStore));
        excludeSender(address(_holderStore));
        excludeSender(address(_timestampStore));
        excludeSender(address(_cashToken1));
        excludeSender(address(_cashToken2));
        excludeSender(address(_powerToken));
        excludeSender(address(_zeroToken));
        excludeSender(address(_emergencyGovernor));
        excludeSender(address(_standardGovernor));
        excludeSender(address(_zeroGovernor));
        excludeSender(address(_registrar));
        excludeSender(address(_vault));

        // Warp to the next epoch to init ZERO balances
        _warpToNextEpoch();
    }

    function invariant_main() public useCurrentTimestamp {
        console2.log(
            "Checking invariants for epoch %s at timestamp %s...",
            _currentEpoch(),
            _timestampStore.currentTimestamp()
        );

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

        assertGe(
            totalVotes_,
            totalSupply_,
            "The sum of POWER token getVotes() should be greater than or equal to the sum of POWER token balanceOf()"
        );

        IPowerToken nextPowerToken_ = _proposalStore.nextPowerToken();

        if (address(nextPowerToken_) != address(0)) {
            uint256 bootstrapEpoch_ = nextPowerToken_.bootstrapEpoch();

            if (_proposalStore.hasExecutedResetToPowerHolders()) {
                for (uint256 i; i < _holderStore.POWER_HOLDER_NUM(); i++) {
                    address powerHolder_ = _holderStore.powerHolders()[i];

                    assertEq(
                        nextPowerToken_.balanceOf(powerHolder_),
                        nextPowerToken_.pastBalanceOf(powerHolder_, bootstrapEpoch_),
                        "POWER token balance for initial POWER holders should be equal to the balance at bootstrap epoch"
                    );

                    assertEq(
                        nextPowerToken_.getVotes(powerHolder_),
                        nextPowerToken_.getPastVotes(powerHolder_, bootstrapEpoch_),
                        "POWER token votes for initial POWER holders should be equal to the votes at bootstrap epoch"
                    );
                }

                for (uint256 i; i < _holderStore.ZERO_HOLDER_NUM(); i++) {
                    address zeroHolder_ = _holderStore.zeroHolders()[i];

                    assertEq(
                        nextPowerToken_.balanceOf(zeroHolder_),
                        0,
                        "POWER token balance for initial ZERO holders should be equal 0"
                    );

                    assertEq(
                        nextPowerToken_.getVotes(zeroHolder_),
                        0,
                        "POWER token votes for initial ZERO holders should be equal to 0"
                    );
                }

                // Set to false now that the reset has been executed and balances checked
                _proposalStore.setHasExecutedResetToPowerHolders(false);
            }

            if (_proposalStore.hasExecutedResetToZeroHolders()) {
                for (uint256 i; i < _holderStore.POWER_HOLDER_NUM(); i++) {
                    address powerHolder_ = _holderStore.powerHolders()[i];

                    assertEq(
                        nextPowerToken_.balanceOf(powerHolder_),
                        0,
                        "POWER token balance for initial POWER holders should be 0 after reset to ZERO holders"
                    );

                    assertEq(
                        nextPowerToken_.getVotes(powerHolder_),
                        0,
                        "POWER token votes for initial POWER holders should be 0 after reset to ZERO holders"
                    );
                }

                for (uint256 i; i < _holderStore.ZERO_HOLDER_NUM(); i++) {
                    address zeroHolder_ = _holderStore.zeroHolders()[i];
                    assertEq(
                        nextPowerToken_.balanceOf(zeroHolder_),
                        nextPowerToken_.pastBalanceOf(zeroHolder_, bootstrapEpoch_),
                        "POWER token balance for initial ZERO holders should be equal to the balance at bootstrap epoch"
                    );

                    assertEq(
                        nextPowerToken_.getVotes(zeroHolder_),
                        nextPowerToken_.getPastVotes(zeroHolder_, bootstrapEpoch_),
                        "POWER token votes for initial ZERO holders should be equal to the balance at bootstrap epoch"
                    );
                }

                // Set to false now that the reset has been executed and balances checked
                _proposalStore.setHasExecutedResetToZeroHolders(false);
            }
        }

        if (_proposalStore.nextPowerTargetEpoch() != 0) {
            if (!_isTransferEpoch(_currentEpoch())) _warpToNextEpoch();

            if (_proposalStore.nextPowerTargetEpoch() + 1 == _currentEpoch()) {
                uint256 nextPowerTargetVotes_ = _proposalStore.nextPowerTargetVotes();
                uint256 nextPowerTargetSupply_ = _proposalStore.nextPowerTargetSupply();

                assertEq(
                    totalVotes_,
                    nextPowerTargetVotes_,
                    "POWER token total votes should account for inflation and equal the target votes"
                );

                assertEq(
                    _powerToken.totalSupply() + _powerToken.amountToAuction(),
                    nextPowerTargetSupply_,
                    "POWER token totalSupply() should account for inflation and equal the target supply"
                );

                assertEq(
                    _zeroToken.totalSupply(),
                    _proposalStore.nextZeroTargetSupply(),
                    "ZERO token totalSupply() should account for inflation and equal the target supply"
                );
            }
        }
    }
}

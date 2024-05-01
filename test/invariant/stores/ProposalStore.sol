// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { console2 } from "../../../lib/forge-std/src/Test.sol";

import { IGovernor } from "../../../src/abstract/interfaces/IGovernor.sol";
import { IBatchGovernor } from "../../../src/abstract/interfaces/IBatchGovernor.sol";

import { IPowerTokenDeployer } from "../../../src/interfaces/IPowerTokenDeployer.sol";
import { IPowerToken } from "../../../src/interfaces/IPowerToken.sol";
import { IZeroToken } from "../../../src/interfaces/IZeroToken.sol";
import { IRegistrar } from "../../../src/interfaces/IRegistrar.sol";
import { IEmergencyGovernor } from "../../../src/interfaces/IEmergencyGovernor.sol";
import { IStandardGovernor } from "../../../src/interfaces/IStandardGovernor.sol";
import { IZeroGovernor } from "../../../src/interfaces/IZeroGovernor.sol";

import { ERC20ExtendedHarness } from "../../utils/ERC20ExtendedHarness.sol";
import { TestUtils } from "../../utils/TestUtils.sol";

import { HolderStore } from "./HolderStore.sol";

contract ProposalStore is TestUtils {
    uint16 public nextPowerTargetEpoch;
    uint240 public nextPowerTargetSupply;
    uint240 public nextPowerTargetVotes;
    uint256 public nextZeroTargetSupply;

    mapping(address powerHolder => uint240 nextVotingPower) public nextVotingPower;
    mapping(address powerHolder => uint240 rewards) public zeroRewards;

    IPowerToken public nextPowerToken;

    uint256 public expectedPowerTokenSupply;
    uint256 public expectedZeroTokenSupply;

    bool public hasExecutedResetToPowerHolders;
    bool public hasExecutedResetToZeroHolders;
    bool public hasVotedOnAllStandardProposals;

    HolderStore internal _holderStore;

    IPowerToken internal _powerToken;
    IZeroToken internal _zeroToken;

    IRegistrar internal _registrar;

    IEmergencyGovernor internal _emergencyGovernor;
    IStandardGovernor internal _standardGovernor;
    IZeroGovernor internal _zeroGovernor;

    string[] internal _registrarLists = ["earners", "earners_list_ignored", "minters", "validators"];

    address[] internal _emergencyGovernorTargets;
    uint256[] internal _emergencyGovernorValues;

    address[] internal _standardGovernorTargets;
    uint256[] internal _standardGovernorValues;

    address[] internal _zeroGovernorTargets;
    uint256[] internal _zeroGovernorValues;

    address[] internal _allowedCashTokens;

    uint256[] internal _emergencyGovernorProposalIds;
    uint256[] internal _standardGovernorProposalIds;
    uint256[] internal _zeroGovernorProposalIds;

    mapping(uint256 proposalId => bool hasBeenSubmitted) internal _submittedProposals;
    mapping(uint256 proposalId => bytes proposalCallData) internal _submittedProposalsCallData;

    constructor(
        IRegistrar registrar_,
        IEmergencyGovernor emergencyGovernor_,
        IStandardGovernor standardGovernor_,
        IZeroGovernor zeroGovernor_,
        address[] memory allowedCashTokens_,
        HolderStore holderStore_
    ) {
        _registrar = registrar_;

        _powerToken = IPowerToken(_registrar.powerToken());
        _zeroToken = IZeroToken(_registrar.zeroToken());

        _emergencyGovernor = emergencyGovernor_;
        _emergencyGovernorTargets.push(address(_emergencyGovernor));
        _emergencyGovernorValues.push(0);

        _standardGovernor = standardGovernor_;
        _standardGovernorTargets.push(address(_standardGovernor));
        _standardGovernorValues.push(0);

        _zeroGovernor = zeroGovernor_;
        _zeroGovernorTargets.push(address(_zeroGovernor));
        _zeroGovernorValues.push(0);

        _allowedCashTokens = allowedCashTokens_;
        _holderStore = holderStore_;
    }

    /* ============ Emergency Governor Proposals ============ */

    function emergencyGovernorAddToList(address proposer_, uint256 registrarListSeed_) external {
        console2.log("Start emergencyGovernorAddToList...");
        registrarListSeed_ = bound(registrarListSeed_, 0, _registrarLists.length - 1);

        string memory list_ = _registrarLists[registrarListSeed_];

        // Return early if proposer is in the list
        if (_registrar.listContains(bytes32(bytes(list_)), proposer_)) {
            console2.log("Proposer is already in the list");
            return;
        }

        uint256 proposalId_ = _emergencyGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IEmergencyGovernor.addToList.selector, bytes32(bytes(list_)), proposer_),
            "Add proposer to list"
        );

        if (proposalId_ == 0) {
            console2.log("Emergency proposal to add %s to %s list has already been submitted", proposer_, list_);
            return;
        }

        console2.log("Emergency proposal %s to add %s to %s list created successfully!", proposalId_, proposer_, list_);
    }

    function emergencyGovernorRemoveFromList(
        address proposer_,
        uint256 registrarListSeed_,
        address accountToRemove_
    ) external {
        console2.log("Start emergencyGovernorRemoveFromList...");
        registrarListSeed_ = bound(registrarListSeed_, 0, _registrarLists.length - 1);

        string memory list_ = _registrarLists[registrarListSeed_];

        // Return early if account to remove is not in the list
        if (!_registrar.listContains(bytes32(bytes(list_)), accountToRemove_)) {
            console2.log("Account to remove is not in the list");
            return;
        }

        uint256 proposalId_ = _emergencyGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IEmergencyGovernor.removeFromList.selector, bytes32(bytes(list_)), accountToRemove_),
            "Remove account from list"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Emergency proposal to remove %s from %s list has already been submitted",
                accountToRemove_,
                list_
            );
            return;
        }

        console2.log(
            "Emergency proposal %s to remove %s from %s list created successfully!",
            proposalId_,
            accountToRemove_,
            list_
        );
    }

    function emergencyGovernorRemoveFromAndAddToList(
        address proposer_,
        uint256 registrarListSeed_,
        address accountToRemove_,
        address accountToAdd_
    ) external {
        console2.log("Start emergencyGovernorRemoveFromList...");
        registrarListSeed_ = bound(registrarListSeed_, 0, _registrarLists.length - 1);

        string memory list_ = _registrarLists[registrarListSeed_];

        // Return early if account to remove is not in the list or if account to add is already in the list
        if (
            !_registrar.listContains(bytes32(bytes(list_)), accountToRemove_) ||
            _registrar.listContains(bytes32(bytes(list_)), accountToAdd_)
        ) {
            console2.log("Account to remove is not in the list or account to add is already in the list");
            return;
        }

        uint256 proposalId_ = _emergencyGovernorPropose(
            proposer_,
            abi.encodeWithSelector(
                IEmergencyGovernor.removeFromAndAddToList.selector,
                bytes32(bytes(list_)),
                accountToRemove_,
                accountToAdd_
            ),
            "Remove account from list and add new account to list"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Emergency proposal to remove %s from %s list and add %s has already been submitted",
                accountToRemove_,
                list_,
                accountToAdd_
            );
            return;
        }

        console2.log(
            "Emergency proposal to remove %s from %s list and add %s created successfully!",
            accountToRemove_,
            list_,
            accountToAdd_
        );
    }

    function emergencyGovernorSetKey(address proposer_, uint256 keySeed_, uint256 valueSeed_) external {
        console2.log("Start emergencyGovernorSetKey...");

        string memory key_ = _generateRandomString(keySeed_);
        string memory value_ = _generateRandomString(valueSeed_);

        // Return early if key value pair already exists
        if (_registrar.get(bytes32(bytes(key_))) == bytes32(bytes(value_))) {
            console2.log("Key value pair already exists");
            return;
        }

        uint256 proposalId_ = _emergencyGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IEmergencyGovernor.setKey.selector, bytes32(bytes(key_)), bytes32(bytes(value_))),
            "Set key value pair"
        );

        if (proposalId_ == 0) {
            console2.log("Emergency proposal to set key %s and value %s has already been submitted", key_, value_);
            return;
        }

        console2.log(
            "Emergency proposal %s to set key %s and value %s created successfully!",
            proposalId_,
            key_,
            value_
        );
    }

    function emergencyGovernorSetStandardProposalFee(address proposer_, uint256 proposalFeeSeed_) external {
        console2.log("Start emergencyGovernorSetStandardProposalFee...");

        uint256 proposalFee_ = _generateRandomProposalFee(proposalFeeSeed_);

        uint256 proposalId_ = _emergencyGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IEmergencyGovernor.setStandardProposalFee.selector, proposalFee_),
            "Set Standard Governor proposal fee"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Emergency proposal to set Standard Governor proposal fee to %s has already been submitted",
                proposalFee_
            );
            return;
        }

        console2.log(
            "Emergency proposal %s to set Standard Governor proposal fee to %s created successfully!",
            proposalId_,
            proposalFee_
        );
    }

    /* ============ Standard Governor Proposals ============ */

    function standardGovernorAddToList(address proposer_, uint256 registrarListSeed_) external {
        console2.log("Start standardGovernorAddToList...");
        registrarListSeed_ = bound(registrarListSeed_, 0, _registrarLists.length - 1);

        string memory list_ = _registrarLists[registrarListSeed_];

        // Return early if proposer is in the list
        if (_registrar.listContains(bytes32(bytes(list_)), proposer_)) {
            console2.log("Proposer is already in the list");
            return;
        }

        uint256 proposalId_ = _standardGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IStandardGovernor.addToList.selector, bytes32(bytes(list_)), proposer_),
            "Add proposer to list"
        );

        if (proposalId_ == 0) {
            console2.log("Standard proposal to add %s to %s list has already been submitted", proposer_, list_);
            return;
        }

        console2.log("Standard proposal %s to add %s to %s list created successfully!", proposalId_, proposer_, list_);
    }

    function standardGovernorRemoveFromList(
        address proposer_,
        uint256 registrarListSeed_,
        address accountToRemove_
    ) external {
        console2.log("Start standardGovernorRemoveFromList...");
        registrarListSeed_ = bound(registrarListSeed_, 0, _registrarLists.length - 1);

        string memory list_ = _registrarLists[registrarListSeed_];

        // Return early if account to remove is not in the list
        if (!_registrar.listContains(bytes32(bytes(list_)), accountToRemove_)) {
            console2.log("Account to remove is not in the list");
            return;
        }

        uint256 proposalId_ = _standardGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IStandardGovernor.removeFromList.selector, bytes32(bytes(list_)), accountToRemove_),
            "Remove account from list"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Standard proposal to remove %s from %s list has already been submitted",
                accountToRemove_,
                list_
            );
            return;
        }

        console2.log(
            "Standard proposal %s to remove %s from %s list created successfully!",
            proposalId_,
            accountToRemove_,
            list_
        );
    }

    function standardGovernorRemoveFromAndAddToList(
        address proposer_,
        uint256 registrarListSeed_,
        address accountToRemove_,
        address accountToAdd_
    ) external {
        console2.log("Start standardGovernorRemoveFromList...");
        registrarListSeed_ = bound(registrarListSeed_, 0, _registrarLists.length - 1);

        string memory list_ = _registrarLists[registrarListSeed_];

        // Return early if account to remove is not in the list or if account to add is already in the list
        if (
            !_registrar.listContains(bytes32(bytes(list_)), accountToRemove_) ||
            _registrar.listContains(bytes32(bytes(list_)), accountToAdd_)
        ) {
            console2.log("Account to remove is not in the list or account to add is already in the list");
            return;
        }

        uint256 proposalId_ = _standardGovernorPropose(
            proposer_,
            abi.encodeWithSelector(
                IStandardGovernor.removeFromAndAddToList.selector,
                bytes32(bytes(list_)),
                accountToRemove_,
                accountToAdd_
            ),
            "Remove account from list and add new account to list"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Standard proposal to remove %s from %s list and add %s has already been submitted",
                accountToRemove_,
                list_,
                accountToAdd_
            );
            return;
        }

        console2.log(
            "Standard proposal to remove %s from %s list and add %s created successfully!",
            accountToRemove_,
            list_,
            accountToAdd_
        );
    }

    function standardGovernorSetKey(address proposer_, uint256 keySeed_, uint256 valueSeed_) external {
        console2.log("Start standardGovernorSetKey...");

        string memory key_ = _generateRandomString(keySeed_);
        string memory value_ = _generateRandomString(valueSeed_);

        // Return early if key value pair already exists
        if (_registrar.get(bytes32(bytes(key_))) == bytes32(bytes(value_))) {
            console2.log("Key value pair already exists");
            return;
        }

        uint256 proposalId_ = _standardGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IStandardGovernor.setKey.selector, bytes32(bytes(key_)), bytes32(bytes(value_))),
            "Set key value pair"
        );

        if (proposalId_ == 0) {
            console2.log("Standard proposal to set key %s and value %s has already been submitted", key_, value_);
            return;
        }

        console2.log(
            "Standard proposal %s to set key %s and value %s created successfully!",
            proposalId_,
            key_,
            value_
        );
    }

    function standardGovernorSetProposalFee(address proposer_, uint256 proposalFeeSeed_) external {
        console2.log("Start standardGovernorSetProposalFee...");

        uint256 proposalFee_ = _generateRandomProposalFee(proposalFeeSeed_);

        uint256 proposalId_ = _standardGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IStandardGovernor.setProposalFee.selector, proposalFee_),
            "Set proposal fee"
        );

        if (proposalId_ == 0) {
            console2.log("Standard proposal to set proposal fee to %s has already been submitted", proposalFee_);
            return;
        }

        console2.log("Standard proposal %s to set proposal fee to %s created successfully!", proposalId_, proposalFee_);
    }

    /* ============ Zero Governor Proposals ============ */

    function zeroGovernorResetToPowerHolders(address proposer_) external {
        console2.log("Start zeroGovernorResetToPowerHolders...");

        uint256 proposalId_ = _zeroGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IZeroGovernor.resetToPowerHolders.selector),
            "Reset to POWER holders"
        );

        if (proposalId_ == 0) {
            console2.log("Zero proposal to reset to POWER holders has already been submitted");
            return;
        }

        console2.log("Zero proposal %s to reset to POWER holders created successfully!", proposalId_);
    }

    function zeroGovernorResetToZeroHolders(address proposer_) external {
        console2.log("Start zeroGovernorResetToZeroHolders...");

        uint256 proposalId_ = _zeroGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IZeroGovernor.resetToZeroHolders.selector),
            "Reset to ZERO holders"
        );

        if (proposalId_ == 0) {
            console2.log("Zero proposal to reset to ZERO holders has already been submitted");
            return;
        }

        console2.log("Zero proposal %s to reset to ZERO holders created successfully!", proposalId_);
    }

    function zeroGovernorSetCashToken(address proposer_, uint256 cashTokenSeed_, uint256 proposalFeeSeed_) external {
        console2.log("Start zeroGovernorSetCashToken...");
        cashTokenSeed_ = bound(cashTokenSeed_, 0, _allowedCashTokens.length - 1);

        address cashToken_ = _allowedCashTokens[cashTokenSeed_];
        uint256 proposalFee_ = _generateRandomProposalFee(proposalFeeSeed_);

        // Return early if cash token is already set
        if (_standardGovernor.cashToken() == cashToken_) {
            console2.log("Cash token is already set");
            return;
        }

        uint256 proposalId_ = _zeroGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IZeroGovernor.setCashToken.selector, cashToken_, proposalFee_),
            "Set cash token"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Zero proposal to set cash token to %s and proposal fee to %s has already been submitted",
                cashToken_,
                proposalFee_
            );
            return;
        }

        console2.log(
            "Zero proposal %s to set cash token to %s and proposal fee to %s created successfully!",
            proposalId_,
            cashToken_,
            proposalFee_
        );
    }

    function zeroGovernorSetEmergencyProposalThresholdRatio(
        address proposer_,
        uint256 emergencyProposalThresholdRatioSeed_
    ) external {
        console2.log("Start zeroGovernorSetEmergencyProposalThresholdRatio...");

        uint16 emergencyProposalThresholdRatio_ = _generateRandomThresholdRatio(emergencyProposalThresholdRatioSeed_);

        uint256 proposalId_ = _zeroGovernorPropose(
            proposer_,
            abi.encodeWithSelector(
                IZeroGovernor.setEmergencyProposalThresholdRatio.selector,
                emergencyProposalThresholdRatio_
            ),
            "Set Emergency Proposal Threshold Ratio"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Zero proposal to set Emergency Proposal Threshold Ratio to %s has already been submitted",
                emergencyProposalThresholdRatio_
            );
            return;
        }

        console2.log(
            "Zero proposal %s to set Emergency Proposal Threshold Ratio to %s created successfully!",
            proposalId_,
            emergencyProposalThresholdRatio_
        );
    }

    function zeroGovernorSetZeroProposalThresholdRatio(
        address proposer_,
        uint256 zeroProposalThresholdRatioSeed_
    ) external {
        console2.log("Start zeroGovernorSetZeroProposalThresholdRatio...");

        uint16 zeroProposalThresholdRatio_ = _generateRandomThresholdRatio(zeroProposalThresholdRatioSeed_);

        uint256 proposalId_ = _zeroGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IZeroGovernor.setZeroProposalThresholdRatio.selector, zeroProposalThresholdRatio_),
            "Set Zero Proposal Threshold Ratio"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Zero proposal to set Zero Proposal Threshold Ratio to %s has already been submitted",
                zeroProposalThresholdRatio_
            );
            return;
        }

        console2.log(
            "Zero proposal %s to set Zero Proposal Threshold Ratio to %s created successfully!",
            proposalId_,
            zeroProposalThresholdRatio_
        );
    }

    /* ============ Vote on proposal ============ */

    function voteOnEmergencyGovernorProposal(
        uint256 proposalIdSeed_,
        uint256 supportSeed_,
        address[] memory accounts_
    ) external {
        console2.log("Start voteOnEmergencyGovernorProposal...");

        if (!_hasProposalsBeenQueued(_emergencyGovernorProposalIds)) return;

        proposalIdSeed_ = bound(proposalIdSeed_, 0, _emergencyGovernorProposalIds.length - 1);
        uint256 proposalId_ = _emergencyGovernorProposalIds[proposalIdSeed_];

        if (_hasProposalBeenExecuted(proposalId_)) return;

        (, , IGovernor.ProposalState state_, , , , , ) = _emergencyGovernor.getProposal(proposalId_);

        if (!_isProposalActive(state_, proposalId_)) return;

        console2.log("Voting on Emergency proposal %s...", proposalId_);

        address account_;

        for (uint256 i; i < accounts_.length; i++) {
            (, , state_, , , , , ) = _emergencyGovernor.getProposal(proposalId_);

            if (!_isProposalActive(state_, proposalId_)) break;

            account_ = accounts_[i];

            if (_emergencyGovernor.hasVoted(proposalId_, account_)) {
                console2.log("Account %s has already voted on Emergency proposal %s", account_, proposalId_);
                continue;
            }

            uint8 support_ = _getSupport(supportSeed_, account_);

            vm.prank(account_);
            _emergencyGovernor.castVote(proposalId_, support_);

            console2.log(
                "Account %s casted a %s vote on Emergency proposal %s",
                account_,
                support_ == 1 ? "Yes" : "No",
                proposalId_
            );
        }

        (, , state_, , , , , ) = _emergencyGovernor.getProposal(proposalId_);

        console2.log("State of Emergency proposal %s after voting: %s", proposalId_, _translateState(state_));
    }

    function voteOnStandardGovernorProposal(
        uint256 proposalId_,
        uint256 supportSeed_,
        address[] memory accounts_
    ) external {
        console2.log("Start voteOnStandardGovernorProposal...");

        if (_hasProposalBeenExecuted(proposalId_)) return;

        (uint48 voteStart_, , IGovernor.ProposalState state_, , , , ) = _standardGovernor.getProposal(proposalId_);

        if (!_isProposalActive(state_, proposalId_)) return;

        console2.log("Voting on Standard proposal %s...", proposalId_);

        address account_;

        for (uint256 i; i < accounts_.length; i++) {
            (, , state_, , , , ) = _standardGovernor.getProposal(proposalId_);

            account_ = accounts_[i];

            if (_standardGovernor.hasVotedOnAllProposals(account_, voteStart_)) {
                console2.log("Account %s has already voted on all Standard proposals", account_);
                continue;
            }

            if (_standardGovernor.hasVoted(proposalId_, account_)) {
                console2.log("Account %s has already voted on Standard proposal %s", account_, proposalId_);
                continue;
            }

            uint8 support_ = _getSupport(supportSeed_, account_);

            uint256 votingPower_ = _powerToken.getVotes(account_);
            uint256 zeroBalanceBefore_ = _zeroToken.balanceOf(account_);
            uint256 zeroTotalSupplyBefore_ = _zeroToken.totalSupply();

            vm.prank(account_);
            _standardGovernor.castVote(proposalId_, support_);

            console2.log(
                "Account %s casted a %s vote on Standard proposal %s",
                account_,
                support_ == 1 ? "Yes" : "No",
                proposalId_
            );

            // Return early if account has not voted on all proposals yet and received their ZERO rewards
            if (!_standardGovernor.hasVotedOnAllProposals(account_, voteStart_)) continue;

            uint256 zeroRewards_ = _getZeroTokenReward(account_, _powerToken, _standardGovernor, voteStart_);

            // Verify that ZERO rewards have been distributed
            assertEq(_zeroToken.balanceOf(account_), zeroBalanceBefore_ + zeroRewards_);

            // Verify that the ZERO total supply has increased accordingly
            assertEq(_zeroToken.totalSupply(), zeroTotalSupplyBefore_ + zeroRewards_);

            // Increase expected ZERO token target supply for the current epoch
            nextZeroTargetSupply = zeroTotalSupplyBefore_ + zeroRewards_;

            uint240 nextVotingPower_ = _getNextVotingPower(_powerToken, votingPower_);
            console2.log("Next voting power for account %s: %s", account_, nextVotingPower_);

            zeroRewards[account_] += uint240(zeroRewards_);
            nextVotingPower[account_] = nextVotingPower_;

            // Reset next power taget votes before accounting for the next voting power
            if (i == 0) {
                nextPowerTargetVotes = 0;
            }

            // Set expected POWER token target votes for the next voting epoch
            nextPowerTargetVotes += nextVotingPower_;
            hasVotedOnAllStandardProposals = true;
        }

        (, , state_, , , , ) = _standardGovernor.getProposal(proposalId_);

        console2.log("State of Standard proposal %s after voting: %s", proposalId_, _translateState(state_));
    }

    function voteOnZeroGovernorProposal(
        uint256 proposalIdSeed_,
        uint256 supportSeed_,
        address[] memory accounts_
    ) external {
        console2.log("Start voteOnZeroGovernorProposal...");

        if (!_hasProposalsBeenQueued(_zeroGovernorProposalIds)) return;

        proposalIdSeed_ = bound(proposalIdSeed_, 0, _zeroGovernorProposalIds.length - 1);
        uint256 proposalId_ = _zeroGovernorProposalIds[proposalIdSeed_];

        if (_hasProposalBeenExecuted(proposalId_)) return;

        (uint48 voteStart_, , IGovernor.ProposalState state_, , , , , ) = _zeroGovernor.getProposal(proposalId_);

        if (!_isProposalActive(state_, proposalId_)) return;

        console2.log("Voting on ZERO proposal %s...", proposalId_);

        address account_;

        for (uint256 i; i < accounts_.length; i++) {
            (, , state_, , , , , ) = _zeroGovernor.getProposal(proposalId_);

            if (!_isProposalActive(state_, proposalId_)) break;

            account_ = accounts_[i];

            if (_zeroGovernor.hasVoted(proposalId_, account_)) {
                console2.log("Account %s has already voted on Zero proposal %s", account_, proposalId_);
                continue;
            }

            // If reset to ZERO holders has occured and account does not have voting power yet, switch to previous ZERO holder
            if (hasExecutedResetToZeroHolders && _zeroToken.getPastVotes(account_, voteStart_ - 2) == 0) {
                account_ = _holderStore.powerHolders()[i];
            }

            uint8 support_ = _getSupport(supportSeed_, account_);

            vm.prank(account_);
            _zeroGovernor.castVote(proposalId_, support_);

            console2.log(
                "Account %s casted a %s vote on Zero proposal %s",
                account_,
                support_ == 1 ? "Yes" : "No",
                proposalId_
            );
        }

        console2.log("State of ZERO proposal %s after voting: %s", proposalId_, _translateState(state_));
    }

    /* ============ Execute proposal ============ */

    function executeEmergencyGovernorProposal(uint256 proposalIdSeed_) external {
        console2.log("Start executeEmergencyGovernorProposal...");

        if (!_hasProposalsBeenQueued(_emergencyGovernorProposalIds)) return;

        proposalIdSeed_ = bound(proposalIdSeed_, 0, _emergencyGovernorProposalIds.length - 1);
        uint256 proposalId_ = _emergencyGovernorProposalIds[proposalIdSeed_];

        if (_hasProposalBeenExecuted(proposalId_)) return;

        (, , IGovernor.ProposalState state_, , , , , ) = _emergencyGovernor.getProposal(proposalId_);

        if (!_hasProposalSucceeded(state_, proposalId_)) return;

        console2.log("Executing Emergency proposal %s", proposalId_);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = _submittedProposalsCallData[proposalId_];

        address[] memory targets_ = new address[](1);
        uint256[] memory values_ = new uint256[](1);

        _emergencyGovernor.execute(targets_, values_, callDatas_, keccak256(""));

        console2.log("Emergency proposal %s executed successfully!", proposalId_);

        delete _emergencyGovernorProposalIds[proposalIdSeed_];
    }

    function executeStandardGovernorProposal(uint256 proposalId_) external {
        console2.log("Start executeStandardGovernorProposal...");

        if (_hasProposalBeenExecuted(proposalId_)) return;

        (, , IGovernor.ProposalState state_, , , , ) = _standardGovernor.getProposal(proposalId_);

        if (!_hasProposalSucceeded(state_, proposalId_)) return;

        console2.log("Executing Standard proposal %s", proposalId_);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = _submittedProposalsCallData[proposalId_];

        address[] memory targets_ = new address[](1);
        uint256[] memory values_ = new uint256[](1);

        _standardGovernor.execute(targets_, values_, callDatas_, keccak256(""));

        console2.log("Standard proposal %s executed successfully!", proposalId_);

        _standardGovernorProposalIds.pop();
    }

    function executeZeroGovernorProposal(uint256 proposalIdSeed_) external {
        console2.log("Start executeZeroGovernorProposal...");

        if (!_hasProposalsBeenQueued(_zeroGovernorProposalIds)) return;

        proposalIdSeed_ = bound(proposalIdSeed_, 0, _zeroGovernorProposalIds.length - 1);
        uint256 proposalId_ = _zeroGovernorProposalIds[proposalIdSeed_];

        if (_hasProposalBeenExecuted(proposalId_)) return;

        (, , IGovernor.ProposalState state_, , , , , ) = _zeroGovernor.getProposal(proposalId_);

        if (!_hasProposalSucceeded(state_, proposalId_)) return;

        console2.log("Executing Zero proposal %s", proposalId_);

        bytes memory callData_ = _submittedProposalsCallData[proposalId_];

        bytes memory resetToPowerHoldersCallData = abi.encodeWithSelector(IZeroGovernor.resetToPowerHolders.selector);
        bytes memory resetToZeroHoldersCallData = abi.encodeWithSelector(IZeroGovernor.resetToZeroHolders.selector);

        if (
            keccak256(callData_) == keccak256(resetToPowerHoldersCallData) ||
            keccak256(callData_) == keccak256(resetToZeroHoldersCallData)
        ) {
            nextPowerToken = IPowerToken(IPowerTokenDeployer(_registrar.powerTokenDeployer()).nextDeploy());
        }

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = callData_;

        address[] memory targets_ = new address[](1);
        uint256[] memory values_ = new uint256[](1);

        _zeroGovernor.execute(targets_, values_, callDatas_, keccak256(""));

        console2.log("Zero proposal %s executed successfully!", proposalId_);

        if (keccak256(callData_) == keccak256(resetToPowerHoldersCallData)) {
            setHasExecutedResetToPowerHolders(true);
        }

        address[] memory prevPowerHolders_ = _holderStore.powerHolders();

        if (keccak256(callData_) == keccak256(resetToZeroHoldersCallData)) {
            setHasExecutedResetToZeroHolders(true);

            console2.log("Swap holder store addresses...");

            // Swap addresses now that the power has been reset to ZERO holders
            _holderStore.setPowerHolders(_holderStore.zeroHolders());
            _holderStore.setZeroHolders(prevPowerHolders_);

            assertEq(prevPowerHolders_[0], _holderStore.zeroHolders()[0], "Failed to swap holder store addressess");
        }

        // Set new contracts addresses and clear pending proposal ids if reset has occured
        if (
            keccak256(callData_) == keccak256(resetToPowerHoldersCallData) ||
            keccak256(callData_) == keccak256(resetToZeroHoldersCallData)
        ) {
            // If all standard proposals have been voted on before the reset, the inflation is lost
            if (hasVotedOnAllStandardProposals) {
                hasVotedOnAllStandardProposals = false;
            }

            _powerToken = IPowerToken(_registrar.powerToken());
            _zeroToken = IZeroToken(_registrar.zeroToken());

            _emergencyGovernor = IEmergencyGovernor(_registrar.emergencyGovernor());
            _emergencyGovernorTargets.pop();
            _emergencyGovernorTargets.push(address(_emergencyGovernor));

            _standardGovernor = IStandardGovernor(_registrar.standardGovernor());
            _standardGovernorTargets.pop();
            _standardGovernorTargets.push(address(_standardGovernor));

            delete _emergencyGovernorProposalIds;
            delete _standardGovernorProposalIds;
        }

        delete _zeroGovernorProposalIds[proposalIdSeed_];
    }

    /* ============ Getters ============ */

    function getStandardGovernorProposalIds() external view returns (uint256[] memory) {
        return _standardGovernorProposalIds;
    }

    /* ============ Setters ============ */

    function setHasExecutedResetToPowerHolders(bool hasExecuted_) public {
        hasExecutedResetToPowerHolders = hasExecuted_;
    }

    function setHasExecutedResetToZeroHolders(bool hasExecuted_) public {
        hasExecutedResetToZeroHolders = hasExecuted_;
    }

    function setHasVotedOnAllStandardProposals(bool hasVoted_) public {
        hasVotedOnAllStandardProposals = hasVoted_;
    }

    function setNextPowerTargetEpoch(uint16 nextPowerTargetEpoch_) public {
        nextPowerTargetEpoch = nextPowerTargetEpoch_;
    }

    function setNextPowerToken(address nextPowerToken_) public {
        nextPowerToken = IPowerToken(nextPowerToken_);
    }

    function setNextVotingPower(address account_, uint240 nextVotingPower_) public {
        nextVotingPower[account_] = nextVotingPower_;
    }

    function setZeroRewards(address account_, uint240 zeroRewards_) public {
        zeroRewards[account_] = zeroRewards_;
    }

    /* ============ Helpers ============ */

    /* ============ Propose Helpers ============ */

    function _emergencyGovernorPropose(
        address proposer_,
        bytes memory callData_,
        string memory description_
    ) internal returns (uint256 proposalId_) {
        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = callData_;

        uint256 expectedProposalId_ = _emergencyGovernor.hashProposal(callDatas_[0]);

        // Return early if proposal has already been submitted
        if (_submittedProposals[expectedProposalId_]) return 0;

        vm.prank(proposer_);
        proposalId_ = _emergencyGovernor.propose(
            _emergencyGovernorTargets,
            _emergencyGovernorValues,
            callDatas_,
            description_
        );

        _submittedProposals[proposalId_] = true;
        _submittedProposalsCallData[proposalId_] = callDatas_[0];

        _emergencyGovernorProposalIds.push(proposalId_);
    }

    function _standardGovernorPropose(
        address proposer_,
        bytes memory callData_,
        string memory description_
    ) internal returns (uint256 proposalId_) {
        uint16 currentEpoch_ = _currentEpoch();

        // If this is the first proposal in the epoch, save the next target supply
        if (_standardGovernor.numberOfProposalsAt(currentEpoch_) + 1 == 1) {
            nextPowerTargetEpoch = currentEpoch_ + (_isVotingEpoch(currentEpoch_) ? 2 : 1);
            nextPowerTargetSupply = _getNextTargetSupply(_powerToken);
        }

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = callData_;

        uint256 expectedProposalId_ = _standardGovernor.hashProposal(callDatas_[0]);

        // Return early if proposal has already been submitted
        if (_submittedProposals[expectedProposalId_]) return 0;

        ERC20ExtendedHarness cashToken_ = ERC20ExtendedHarness(_standardGovernor.cashToken());
        cashToken_.mint(proposer_, _standardGovernor.proposalFee());

        vm.prank(proposer_);
        cashToken_.approve(address(_standardGovernor), type(uint256).max);

        vm.prank(proposer_);
        proposalId_ = _standardGovernor.propose(
            _standardGovernorTargets,
            _standardGovernorValues,
            callDatas_,
            description_
        );

        _submittedProposals[proposalId_] = true;
        _submittedProposalsCallData[proposalId_] = callDatas_[0];

        _standardGovernorProposalIds.push(proposalId_);
    }

    function _zeroGovernorPropose(
        address proposer_,
        bytes memory callData_,
        string memory description_
    ) internal returns (uint256 proposalId_) {
        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = callData_;

        uint256 expectedProposalId_ = _zeroGovernor.hashProposal(callDatas_[0]);

        // Return early if proposal has already been submitted
        if (_submittedProposals[expectedProposalId_]) return 0;

        vm.prank(proposer_);
        proposalId_ = _zeroGovernor.propose(_zeroGovernorTargets, _zeroGovernorValues, callDatas_, description_);

        _submittedProposals[proposalId_] = true;
        _submittedProposalsCallData[proposalId_] = callDatas_[0];

        _zeroGovernorProposalIds.push(proposalId_);
    }

    /* ============ Random values Helpers ============ */

    function _generateRandomProposalFee(uint256 seed_) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(vm.getBlockTimestamp(), seed_))) % 1e18;
    }

    // Generates a random number between 271 and 10_000 (exclusive)
    function _generateRandomThresholdRatio(uint256 seed_) internal view returns (uint16) {
        return uint16(uint256(keccak256(abi.encodePacked(vm.getBlockTimestamp(), seed_))) % (10_000 - 271)) + 271;
    }

    function _generateRandomString(uint256 seed_) internal pure returns (string memory) {
        bytes memory characters_ = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        uint256 stringLength_ = 32;
        bytes memory randomString_ = new bytes(stringLength_);

        for (uint256 i = 0; i < stringLength_; i++) {
            // Generate a random index based on the seed
            randomString_[i] = characters_[uint256(keccak256(abi.encodePacked(seed_, i))) % characters_.length];
        }

        return string(randomString_);
    }

    /* ============ Vote Helpers ============ */

    function _hasProposalsBeenQueued(uint256[] memory proposalIds_) internal pure returns (bool) {
        // Return early if no proposals have been queued.
        if (proposalIds_.length == 0) {
            console2.log("No proposals have been queued...");
            return false;
        }

        return true;
    }

    function _hasProposalBeenExecuted(uint256 proposalId_) internal pure returns (bool) {
        // Return early if the proposal has already been executed.
        if (proposalId_ == 0) {
            console2.log("Proposal %s has already been executed...");
            return true;
        }

        return false;
    }

    function _hasProposalSucceeded(IGovernor.ProposalState state_, uint256 proposalId_) internal pure returns (bool) {
        // Return early if the proposal is not executable.
        if (state_ != IGovernor.ProposalState.Succeeded) {
            console2.log("Proposal %s is not executable. State: %s", proposalId_, _translateState(state_));
            return false;
        }

        return true;
    }

    function _isProposalActive(IGovernor.ProposalState state_, uint256 proposalId_) internal pure returns (bool) {
        // Return early if the proposal is not active.
        if (state_ != IGovernor.ProposalState.Active) {
            console2.log("Proposal %s is not active. State: %s", proposalId_, _translateState(state_));
            return false;
        }

        return true;
    }

    function _getSupport(uint256 supportSeed_, address account_) internal pure returns (uint8) {
        // Generate a random number between 0 and 99 (inclusive)
        return
            (uint256(keccak256(abi.encodePacked(supportSeed_, account_))) % 100) % 2 == 0
                ? uint8(IBatchGovernor.VoteType.Yes)
                : uint8(IBatchGovernor.VoteType.No);
    }

    /* ============ State Helpers ============ */

    function _translateState(IGovernor.ProposalState state_) internal pure returns (string memory) {
        if (state_ == IGovernor.ProposalState.Pending) {
            return "Pending";
        } else if (state_ == IGovernor.ProposalState.Active) {
            return "Active";
        } else if (state_ == IGovernor.ProposalState.Defeated) {
            return "Defeated";
        } else if (state_ == IGovernor.ProposalState.Succeeded) {
            return "Succeeded";
        } else if (state_ == IGovernor.ProposalState.Expired) {
            return "Expired";
        } else if (state_ == IGovernor.ProposalState.Executed) {
            return "Executed";
        }

        return "Unknown";
    }
}

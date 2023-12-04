// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { console2 } from "../lib/forge-std/src/console2.sol";

import { IEmergencyGovernor } from "../src/interfaces/IEmergencyGovernor.sol";
import { IEmergencyGovernorDeployer } from "../src/interfaces/IEmergencyGovernorDeployer.sol";
import { IPowerToken } from "../src/interfaces/IPowerToken.sol";
import { IPowerTokenDeployer } from "../src/interfaces/IPowerTokenDeployer.sol";
import { IRegistrar } from "../src/interfaces/IRegistrar.sol";
import { IStandardGovernor } from "../src/interfaces/IStandardGovernor.sol";
import { IStandardGovernorDeployer } from "../src/interfaces/IStandardGovernorDeployer.sol";
import { IZeroGovernor } from "../src/interfaces/IZeroGovernor.sol";
import { IZeroToken } from "../src/interfaces/IZeroToken.sol";

import { DeployBase } from "../script/DeployBase.s.sol";

import { ERC20PermitHarness } from "./utils/ERC20PermitHarness.sol";
import { TestUtils } from "./utils/TestUtils.sol";

// TODO: test_UserVoteInflationAfterVotingOnAllProposals
// TODO: test_DelegateValueRewardsAfterVotingOnAllProposals

contract IntegrationTests is TestUtils {
    address internal _deployer = makeAddr("deployer");

    IRegistrar internal _registrar;

    ERC20PermitHarness internal _cashToken1 = new ERC20PermitHarness("Cash Token 1", "CASH1", 6);
    ERC20PermitHarness internal _cashToken2 = new ERC20PermitHarness("Cash Token 1", "CASH2", 6);

    address[] internal _allowedCashTokens = [address(_cashToken1), address(_cashToken2)];

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");
    address internal _dave = makeAddr("dave");
    address internal _eve = makeAddr("eve");
    address internal _frank = makeAddr("frank");

    address[] internal _initialPowerAccounts = [_alice, _bob, _carol];

    uint256[] internal _initialPowerBalances = [55, 25, 20];

    address[] internal _initialZeroAccounts = [_dave, _eve, _frank];

    uint256[] internal _initialZeroBalances = [60_000_000, 30_000_000, 10_000_000];

    uint256 internal _standardProposalFee = 1_000;

    DeployBase internal _deploy;

    function setUp() external {
        _deploy = new DeployBase();

        address registrar_ = _deploy.deploy(
            _deployer,
            _initialPowerAccounts,
            _initialPowerBalances,
            _initialZeroAccounts,
            _initialZeroBalances,
            _standardProposalFee,
            _allowedCashTokens
        );

        _registrar = IRegistrar(registrar_);
    }

    function test_initialState() external {
        IPowerToken powerToken_ = IPowerToken(_registrar.powerToken());

        uint256 initialPowerTotalSupply_;

        for (uint256 index_; index_ < _initialPowerBalances.length; ++index_) {
            initialPowerTotalSupply_ += _initialPowerBalances[index_];
        }

        for (uint256 index_; index_ < _initialPowerAccounts.length; ++index_) {
            assertEq(
                powerToken_.balanceOf(_initialPowerAccounts[index_]),
                (_initialPowerBalances[index_] * powerToken_.INITIAL_SUPPLY()) / initialPowerTotalSupply_
            );
        }

        IZeroToken zeroToken_ = IZeroToken(_registrar.zeroToken());

        for (uint256 index_; index_ < _initialZeroAccounts.length; ++index_) {
            assertEq(zeroToken_.balanceOf(_initialZeroAccounts[index_]), _initialZeroBalances[index_]);
        }
    }

    function test_setKey() external {
        IStandardGovernor standardGovernor_ = IStandardGovernor(_registrar.standardGovernor());

        address[] memory targets_ = new address[](1);
        targets_[0] = address(standardGovernor_);

        uint256[] memory values_ = new uint256[](1);

        bytes32 key_ = "TEST_KEY";
        bytes32 value_ = "TEST_VALUE";

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(standardGovernor_.setKey.selector, key_, value_);

        string memory description_ = "Update config key/value pair";

        uint256 proposalFee_ = standardGovernor_.proposalFee();

        _cashToken1.mint(_alice, proposalFee_);

        vm.prank(_alice);
        _cashToken1.approve(address(standardGovernor_), proposalFee_);

        vm.prank(_alice);
        uint256 proposalId_ = standardGovernor_.propose(targets_, values_, callDatas_, description_);

        assertEq(_cashToken1.balanceOf(_alice), 0);
        assertEq(_cashToken1.balanceOf(address(standardGovernor_)), proposalFee_);

        _goToNextVoteEpoch();

        vm.prank(_alice);
        uint256 weight_ = standardGovernor_.castVote(proposalId_, 1);

        assertEq(weight_, 550_000_000);

        _goToNextTransferEpoch();

        standardGovernor_.execute(targets_, values_, callDatas_, bytes32(0));

        assertEq(_registrar.get(key_), value_);

        assertEq(_cashToken1.balanceOf(_alice), proposalFee_);
        assertEq(_cashToken1.balanceOf(address(standardGovernor_)), 0);
    }

    function test_emergencySetKey() external {
        IEmergencyGovernor emergencyGovernor_ = IEmergencyGovernor(_registrar.emergencyGovernor());

        address[] memory targets_ = new address[](1);
        targets_[0] = address(emergencyGovernor_);

        uint256[] memory values_ = new uint256[](1);

        bytes32 key_ = "TEST_KEY";
        bytes32 value_ = "TEST_VALUE";

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(emergencyGovernor_.setKey.selector, key_, value_);

        string memory description_ = "Emergency update config key/value pair";

        vm.prank(_alice);
        uint256 proposalId_ = emergencyGovernor_.propose(targets_, values_, callDatas_, description_);

        vm.prank(_alice);
        uint256 weight_ = emergencyGovernor_.castVote(proposalId_, 1);

        assertEq(weight_, 550_000_000);

        emergencyGovernor_.execute(targets_, values_, callDatas_, bytes32(0));

        assertEq(_registrar.get(key_), value_);
    }

    function test_setCashToken() external {
        IZeroGovernor zeroGovernor_ = IZeroGovernor(_registrar.zeroGovernor());

        address[] memory targets_ = new address[](1);
        targets_[0] = address(zeroGovernor_);

        uint256[] memory values_ = new uint256[](1);

        uint256 newProposalFee_ = zeroGovernor_.proposalFee() * 2;

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(
            zeroGovernor_.setCashToken.selector,
            address(_cashToken2),
            newProposalFee_
        );

        string memory description_ = "Set new cash token and double proposal fee";

        _goToNextEpoch();

        vm.prank(_dave);
        uint256 proposalId_ = zeroGovernor_.propose(targets_, values_, callDatas_, description_);

        vm.prank(_dave);
        uint256 weight_ = zeroGovernor_.castVote(proposalId_, 1);

        assertEq(weight_, 60_000_000);

        zeroGovernor_.execute(targets_, values_, callDatas_, bytes32(0));

        IStandardGovernor standardGovernor_ = IStandardGovernor(_registrar.standardGovernor());

        assertEq(standardGovernor_.cashToken(), address(_cashToken2));
        assertEq(standardGovernor_.proposalFee(), newProposalFee_);
    }

    function test_reset_toZeroHolder() external {
        IRegistrar registrar_ = _registrar;
        IZeroGovernor zeroGovernor_ = IZeroGovernor(registrar_.zeroGovernor());

        _jumpToEpoch(zeroGovernor_.clock() + 1);

        address[] memory targets_ = new address[](1);
        targets_[0] = address(zeroGovernor_);

        uint256[] memory values_ = new uint256[](1);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(zeroGovernor_.resetToZeroHolders.selector);

        string memory description_ = "Reset to Zero holders";

        _goToNextEpoch();

        vm.prank(_dave);
        uint256 proposalId_ = zeroGovernor_.propose(targets_, values_, callDatas_, description_);

        vm.prank(_dave);
        uint256 weight_ = zeroGovernor_.castVote(proposalId_, 1);

        assertEq(weight_, 60_000_000);

        address nextPowerToken_ = IPowerTokenDeployer(registrar_.powerTokenDeployer()).nextDeploy();

        address nextStandardGovernor_ = IStandardGovernorDeployer(registrar_.standardGovernorDeployer()).nextDeploy();

        address nextEmergencyGovernor_ = IEmergencyGovernorDeployer(registrar_.emergencyGovernorDeployer())
            .nextDeploy();

        zeroGovernor_.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

        assertEq(registrar_.powerToken(), nextPowerToken_);
        assertEq(registrar_.standardGovernor(), nextStandardGovernor_);
        assertEq(registrar_.emergencyGovernor(), nextEmergencyGovernor_);

        assertEq(IPowerToken(nextPowerToken_).balanceOf(_alice), 0);
        assertEq(IPowerToken(nextPowerToken_).balanceOf(_bob), 0);
        assertEq(IPowerToken(nextPowerToken_).balanceOf(_carol), 0);
        assertEq(IPowerToken(nextPowerToken_).balanceOf(_dave), 600_000_000);
        assertEq(IPowerToken(nextPowerToken_).balanceOf(_eve), 300_000_000);
        assertEq(IPowerToken(nextPowerToken_).balanceOf(_frank), 100_000_000);
    }

    function test_reset_toPowerHolder() external {
        IRegistrar registrar_ = _registrar;
        IZeroGovernor zeroGovernor_ = IZeroGovernor(registrar_.zeroGovernor());

        _jumpToEpoch(zeroGovernor_.clock() + 1);

        address[] memory targets_ = new address[](1);
        targets_[0] = address(zeroGovernor_);

        uint256[] memory values_ = new uint256[](1);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(zeroGovernor_.resetToPowerHolders.selector);

        string memory description_ = "Reset to Power holders";

        _goToNextEpoch();

        vm.prank(_dave);
        uint256 proposalId_ = zeroGovernor_.propose(targets_, values_, callDatas_, description_);

        vm.prank(_dave);
        uint256 weight_ = zeroGovernor_.castVote(proposalId_, 1);

        assertEq(weight_, 60_000_000);

        address nextPowerToken_ = IPowerTokenDeployer(registrar_.powerTokenDeployer()).nextDeploy();

        address nextStandardGovernor_ = IStandardGovernorDeployer(registrar_.standardGovernorDeployer()).nextDeploy();

        address nextEmergencyGovernor_ = IEmergencyGovernorDeployer(registrar_.emergencyGovernorDeployer())
            .nextDeploy();

        zeroGovernor_.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

        assertEq(registrar_.powerToken(), nextPowerToken_);
        assertEq(registrar_.standardGovernor(), nextStandardGovernor_);
        assertEq(registrar_.emergencyGovernor(), nextEmergencyGovernor_);

        assertEq(IPowerToken(nextPowerToken_).balanceOf(_alice), 550_000_000);
        assertEq(IPowerToken(nextPowerToken_).balanceOf(_bob), 250_000_000);
        assertEq(IPowerToken(nextPowerToken_).balanceOf(_carol), 200_000_000);
        assertEq(IPowerToken(nextPowerToken_).balanceOf(_dave), 0);
        assertEq(IPowerToken(nextPowerToken_).balanceOf(_eve), 0);
        assertEq(IPowerToken(nextPowerToken_).balanceOf(_frank), 0);
    }
}

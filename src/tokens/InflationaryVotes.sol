// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IDualGovernor } from "../governor/IDualGovernor.sol";
import { IInflationaryVotes } from "./ITokens.sol";
import { IRegistrar } from "../registrar/IRegistrar.sol";
import { IVoteDeployer } from "../deployer/IVoteDeployer.sol";

import { ECDSA, ERC20Permit, Math, SafeCast } from "../ImportedContracts.sol";
import { ControlledByRegistrar } from "../registrar/ControlledByRegistrar.sol";
import { PureEpochs } from "../pureEpochs/PureEpochs.sol";

/// @notice ERC20Votes with tracking of balances and more flexible movement of voting power
/// @notice Modified from OpenZeppelin
/// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.6.0/contracts/token/ERC20/extensions/ERC20Votes.sol
/// @dev Decouples voting power and balances for effective rewards distribution to token owners and delegates
abstract contract InflationaryVotes is IInflationaryVotes, ERC20Permit, ControlledByRegistrar {
    struct Checkpoint {
        uint32 fromBlock;
        uint224 amount;
    }

    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    address public immutable governor;

    mapping(address delegator => address delegate) private _delegates;

    mapping(address account => Checkpoint[] voteCheckpoints) private _votesCheckpoints;
    Checkpoint[] private _totalVotesCheckpoints;

    mapping(address account => Checkpoint[] balanceCheckpoints) private _balancesCheckpoints;
    Checkpoint[] private _totalSupplyCheckpoints;

    mapping(address account => uint256 inflation) private _inflation;
    // mapping(address account => uint256 rewards) private _rewards;

    mapping(address account => uint256 epoch) private _delegationSwitchEpoch;
    mapping(address account => uint256 epoch) private _lastEpochInflationAccrued;

    mapping(uint256 epoch => mapping(address account => uint256 amount)) public addedVotes;
    mapping(uint256 epoch => mapping(address account => uint256 amount)) public removedVotes;

    constructor(address registrar_) ControlledByRegistrar(registrar_) {
        // The caller should be a contract/factory that exposes a `governor`.
        // NOTE: `governor` cannot be a constructor argument in as it will affect the address of this contract.
        // NOTE: Technically, for now, `msg.sender` is the VoteDeployer, but this will remain even once the
        //       VoteDeployer is merged into the GovernanceDeployer.
        governor = IVoteDeployer(msg.sender).governor();
    }

    modifier onlyGovernor() {
        if (msg.sender != governor) revert CallerIsNotGovernor();
        _;
    }

    /// @notice Get the address `account` is currently delegating to.
    function delegates(address account) public view virtual returns (address) {
        return _delegates[account];
    }

    /// @notice Gets the current votes balance for `account`
    function getVotes(address account) public view virtual returns (uint256) {
        uint256 pos = _votesCheckpoints[account].length;
        return pos == 0 ? 0 : _votesCheckpoints[account][pos - 1].amount;
    }

    /// @notice Retrieve the number of votes for `account` at the end of `blockNumber`.
    /// @dev `blockNumber` must have been already mined
    function getPastVotes(address account, uint256 blockNumber) public view virtual returns (uint256) {
        if (blockNumber >= block.number) revert InvalidFutureLookup();

        return _checkpointsLookup(_votesCheckpoints[account], blockNumber);
    }

    /// @notice Retrieve the total votes, assuming all votes were delegated.
    /// @dev We assume it is the sum of all the delegated votes, delegation is incentivised.
    /// @dev `blockNumber` must have been already mined
    function getPastTotalVotes(uint256 blockNumber) public view virtual returns (uint256) {
        // TODO: address > vs >= it
        if (blockNumber > block.number) revert InvalidFutureLookup();

        return _checkpointsLookup(_totalVotesCheckpoints, blockNumber);
    }

    /// @notice Return the latest value of total votes.
    function totalVotes() public view virtual returns (uint256) {
        uint256 pos = _totalVotesCheckpoints.length;
        return pos == 0 ? 0 : _totalVotesCheckpoints[pos - 1].amount;
    }

    /// @notice Retrieve the token balance for `account` at the end of `blockNumber`.
    /// @dev `blockNumber` must have been already mined
    function getPastBalance(address account, uint256 blockNumber) public view virtual returns (uint256) {
        // TODO: address > vs >= it
        if (blockNumber > block.number) revert InvalidFutureLookup();

        return _checkpointsLookup(_balancesCheckpoints[account], blockNumber);
    }

    /// @notice Retrieve the `totalSupply` at the end of `blockNumber`. Note, this value is the sum of all balances.
    /// @dev `blockNumber` must have been already mined
    function getPastTotalSupply(uint256 blockNumber) public view virtual returns (uint256) {
        if (blockNumber >= block.number) revert InvalidFutureLookup();

        return _checkpointsLookup(_totalSupplyCheckpoints, blockNumber);
    }

    /// @dev Lookup a value in a list of (sorted) checkpoints.
    function _checkpointsLookup(Checkpoint[] storage checkpoints, uint256 blockNumber) private view returns (uint256) {
        // We run a binary search to look for the earliest checkpoint taken after `blockNumber`.
        //
        // Initially we check if the block is recent to narrow the search range.
        // During the loop, the index of the wanted checkpoint remains in the range [low-1, high).
        // With each iteration, either `low` or `high` is moved towards the middle of the range to maintain the
        //  invariant.
        // - If the middle checkpoint is after `blockNumber`, we look in [low, mid)
        // - If the middle checkpoint is before or equal to `blockNumber`, we look in [mid+1, high)
        // Once we reach a single value (when low == high), we've found the right checkpoint at the index high-1, if not
        // out of bounds (in which case we're looking too far in the past and the result is 0).
        // Note that if the latest checkpoint available is exactly for `blockNumber`, we end up with an index that is
        // past the end of the array, so we technically don't find a checkpoint after `blockNumber`, but it works out
        // the same.
        uint256 length = checkpoints.length;

        uint256 low = 0;
        uint256 high = length;

        if (length > 5) {
            uint256 mid = length - Math.sqrt(length);

            if (_unsafeAccess(checkpoints, mid).fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        while (low < high) {
            uint256 mid = Math.average(low, high);

            if (_unsafeAccess(checkpoints, mid).fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return high == 0 ? 0 : _unsafeAccess(checkpoints, high - 1).amount;
    }

    /// @notice Delegate votes from the sender to `delegatee`.
    function delegate(address delegatee) public virtual {
        _delegate(_msgSender(), delegatee);
    }

    /// @notice Delegates votes from signer to `delegatee`
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (block.timestamp > expiry) revert VotesExpiredSignature(expiry);

        address signer = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(_DELEGATION_TYPEHASH, delegatee, nonce, expiry))),
            v,
            r,
            s
        );

        require(nonce == _useNonce(signer), "InflationaryVotes: invalid nonce");

        _delegate(signer, delegatee);
    }

    /// @notice Claim inflation for all the epochs where delegate was active
    function claimInflation() external returns (uint256) {
        address sender = _msgSender();

        _accrueInflation(sender);

        uint256 reward = _inflation[sender];

        if (reward == 0) return 0;

        _inflation[sender] = 0;

        address currentDelegate = delegates(sender);

        _mint(sender, reward);

        /// prevents double counting of current delegate's voting power
        _burnVotingPower(currentDelegate, reward);

        emit RewardsWithdrawn(sender, currentDelegate, reward);

        return reward;
    }

    /// @dev Maximum token supply. Defaults to `type(uint224).max` (2^224^ - 1).
    function _maxSupply() internal view virtual returns (uint224) {
        return type(uint224).max;
    }

    /// @dev Snapshots the totalSupply and total votes after it has been increased.
    function _mint(address account, uint256 amount) internal virtual override {
        super._mint(account, amount);

        if (totalVotes() > _maxSupply()) revert TotalVotesOverflow();
        if (totalSupply() > _maxSupply()) revert TotalSupplyOverflow();

        _writeCheckpoint(_totalVotesCheckpoints, _add, amount);
        _writeCheckpoint(_totalSupplyCheckpoints, _add, amount);
    }

    /// @notice Adds voting power to active delegate after voting on all proposals
    function addVotingPower(address account, uint256 amount) external onlyGovernor {
        _mintVotingPower(account, amount);

        emit VotingPowerAdded(account, amount);
    }

    /// @dev Adds voting power without changing token balances
    function _mintVotingPower(address account, uint256 amount) internal virtual {
        _writeCheckpoint(_totalVotesCheckpoints, _add, amount);

        if (totalVotes() > _maxSupply()) revert TotalVotesOverflow();

        _moveVotingPower(address(0), account, amount);
    }

    /// @dev Snapshots the totalSupply and total votes after it has been decreased.
    function _burn(address account, uint256 amount) internal virtual override {
        super._burn(account, amount);

        _writeCheckpoint(_totalVotesCheckpoints, _subtract, amount);
        _writeCheckpoint(_totalSupplyCheckpoints, _subtract, amount);
    }

    /// @dev Removes voting power without changing token balances.
    function _burnVotingPower(address account, uint256 amount) internal virtual {
        _writeCheckpoint(_totalVotesCheckpoints, _subtract, amount);
        _moveVotingPower(account, address(0), amount);
    }

    /// @dev Move voting power and update balance checkpoints when tokens are transferred.
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._afterTokenTransfer(from, to, amount);

        _updateBalanceCheckpoints(from, to, amount);
        _moveVotingPower(delegates(from), delegates(to), amount);
    }

    /// @dev Change delegation for `delegator` to `delegatee`.
    function _delegate(address delegator, address delegatee) internal virtual {
        // accrue inflation for previous delegation before switching
        _accrueInflation(delegator);

        address currentDelegate = delegates(delegator);
        uint256 currentEpoch = PureEpochs.currentEpoch();
        uint256 delegatorBalance = balanceOf(delegator) + _inflation[delegator];

        // saved removed votes for current epoch

        // if (_delegationSwitchEpoch[delegator] != currentEpoch) {
        //     removedVotes[currentEpoch][currentDelegate] += delegatorBalance;
        // }

        _delegationSwitchEpoch[delegator] = currentEpoch;
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveVotingPower(currentDelegate, delegatee, delegatorBalance);
    }

    /// @dev Accrue inflation for `delegator` for all the epochs where delegate was active
    /// @dev Called during redelegation or inflation withdrawal
    function _accrueInflation(address delegator) internal virtual {
        // calculate inflation for number of active epochs (delegate voted on all active proposals in these epochs)
        IDualGovernor governor_ = IDualGovernor(governor);
        uint256 currentEpoch = PureEpochs.currentEpoch();

        // no inflation for epoch 0
        if (currentEpoch == 0) return;

        address currentDelegate = delegates(delegator);

        uint256 inflation;
        // uint256 valueReward;
        uint256 startEpoch = _lastEpochInflationAccrued[delegator];

        // TODO make cycle looping safe
        for (uint256 epoch = startEpoch + 1; epoch <= currentEpoch; ++epoch) {
            if (epoch == _delegationSwitchEpoch[delegator] || !governor_.hasFinishedVoting(epoch, currentDelegate)) {
                continue;
            }

            uint256 epochStart = PureEpochs.getBlockNumberOfEpochStart(epoch);
            uint256 balanceAtStartOfEpoch = getPastBalance(delegator, epochStart);
            uint256 delegateFinishedVotingAt = governor_.finishedVotingAt(epoch, currentDelegate);
            uint256 balanceWhenDelegateFinishedVoting = getPastBalance(delegator, delegateFinishedVotingAt);
            uint256 rewardableBalance = inflation + _min(balanceAtStartOfEpoch, balanceWhenDelegateFinishedVoting);

            inflation += IRegistrar(registrar).getInflation(rewardableBalance);
            // valueReward +=
            //     rewardableBalance * IRegistrar(registrar).fixedReward() / getPastTotalBalanceSupply(epochStart);
        }

        _inflation[delegator] += inflation;
        // _valueRewards[delegator] += valueReward;

        // TODO: see if it can be written better
        uint256 lastEpoch = governor_.hasFinishedVoting(currentEpoch, currentDelegate)
            ? currentEpoch
            : currentEpoch - 1;

        _lastEpochInflationAccrued[delegator] = lastEpoch;

        emit InflationAccrued(delegator, currentDelegate, startEpoch, lastEpoch, inflation);

        // TODO: return vote inflation and value rewards amounts ?
    }

    function _moveVotingPower(address src, address dst, uint256 amount) private {
        if (src == dst || amount == 0) return;

        uint256 currentEpoch = PureEpochs.currentEpoch();
        if (addedVotes[currentEpoch][src] >= amount) {
            addedVotes[currentEpoch][src] -= amount;
        } else {
            removedVotes[currentEpoch][src] += (amount - addedVotes[currentEpoch][src]);
        }

        addedVotes[currentEpoch][dst] += amount;

        if (src != address(0)) {
            (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(_votesCheckpoints[src], _subtract, amount);
            emit DelegateVotesChanged(src, oldWeight, newWeight);
        }

        if (dst != address(0)) {
            (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(_votesCheckpoints[dst], _add, amount);
            emit DelegateVotesChanged(dst, oldWeight, newWeight);
        }
    }

    /// @dev Save balances sna when tokens are transferred.
    function _updateBalanceCheckpoints(address src, address dst, uint256 amount) private {
        if (src == dst || amount == 0) return;

        if (src != address(0)) {
            _writeCheckpoint(_balancesCheckpoints[src], _subtract, amount);
        }

        if (dst != address(0)) {
            _writeCheckpoint(_balancesCheckpoints[dst], _add, amount);
        }
    }

    function _writeCheckpoint(
        Checkpoint[] storage checkpoints,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) private returns (uint256 oldWeight, uint256 newWeight) {
        uint256 pos = checkpoints.length;

        Checkpoint memory oldCheckpoint = pos == 0 ? Checkpoint(0, 0) : _unsafeAccess(checkpoints, pos - 1);

        oldWeight = oldCheckpoint.amount;
        newWeight = op(oldWeight, delta);

        if (pos > 0 && oldCheckpoint.fromBlock == block.number) {
            _unsafeAccess(checkpoints, pos - 1).amount = SafeCast.toUint224(newWeight);
        } else {
            checkpoints.push(
                Checkpoint({ fromBlock: SafeCast.toUint32(block.number), amount: SafeCast.toUint224(newWeight) })
            );
        }
    }

    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @dev Access an element of the array without performing bounds check.
    ///      The position is assumed to be within bounds.
    function _unsafeAccess(
        Checkpoint[] storage checkpoints,
        uint256 pos
    ) private pure returns (Checkpoint storage result) {
        assembly {
            mstore(0, checkpoints.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }
}

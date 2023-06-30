// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "src/interfaces/ISPOG.sol";
import "forge-std/console.sol";

/// @notice copy of OZ ERC20Votes which allows more flexible movement of accounts weight
contract InflationaryVotes is IVotes, ERC20Permit, AccessControlEnumerable, ISPOGVotes {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address public spog;

    // Errors
    error CallerIsNotSPOG();
    error AlreadyInitialized();

    struct Checkpoint {
        uint32 fromBlock;
        uint224 votes;
    }

    struct DelegationCycle {
        address previousDelegate;
        uint256 delegateActivity;
        uint256 startEpoch;
        bool previousDelegateRewardAdjusted;
        bool currentDelegateRewardAdjusted;
    }

    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    mapping(address => address) private _delegates;
    mapping(address => Checkpoint[]) private _checkpoints;
    Checkpoint[] private _totalSupplyCheckpoints;

    // owner => current delegation cycle
    mapping(address => DelegationCycle) private _delegationCycles;
    mapping(address => uint256) private _voteRewards;

    /// @notice Constructs governance voting token
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {
        // TODO: Who will be the admin of this contract?
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @notice Sets the spog address. Can only be called once.
    /// @param _spog the address of the spog
    function initializeSPOG(address _spog) external {
        if (spog != address(0)) revert AlreadyInitialized();

        spog = _spog;
        _setupRole(MINTER_ROLE, _spog);
    }

    /**
     * @dev Get the `pos`-th checkpoint for `account`.
     */
    function checkpoints(address account, uint32 pos) public view virtual returns (Checkpoint memory) {
        return _checkpoints[account][pos];
    }

    /**
     * @dev Get number of checkpoints for `account`.
     */
    function numCheckpoints(address account) public view virtual returns (uint32) {
        return SafeCast.toUint32(_checkpoints[account].length);
    }

    /**
     * @dev Get the address `account` is currently delegating to.
     */
    function delegates(address account) public view virtual override returns (address) {
        return _delegates[account];
    }

    /**
     * @dev Gets the current votes balance for `account`
     */
    function getVotes(address account) public view virtual override returns (uint256) {
        uint256 pos = _checkpoints[account].length;
        return pos == 0 ? 0 : _checkpoints[account][pos - 1].votes;
    }

    /**
     * @dev Retrieve the number of votes for `account` at the end of `blockNumber`.
     *
     * Requirements:
     *
     * - `blockNumber` must have been already mined
     */
    function getPastVotes(address account, uint256 blockNumber) public view virtual override returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _checkpointsLookup(_checkpoints[account], blockNumber);
    }

    /**
     * @dev Retrieve the `totalSupply` at the end of `blockNumber`. Note, this value is the sum of all balances.
     * It is but NOT the sum of all the delegated votes!
     *
     * Requirements:
     *
     * - `blockNumber` must have been already mined
     */
    function getPastTotalSupply(uint256 blockNumber) public view virtual override returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _checkpointsLookup(_totalSupplyCheckpoints, blockNumber);
    }

    /// @dev Performs ERC20 transfer with delegation tracking.
    function transfer(address to, uint256 amount) public virtual override(ERC20, IERC20) returns (bool) {
        // cash out rewards
        _accrueRewards(msg.sender);
        _accrueRewards(to);

        _moveVotingPower(_delegates[msg.sender], _delegates[to], amount);

        return super.transfer(to, amount);
    }

    /// @dev Performs ERC20 transferFrom with delegation tracking.
    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override(ERC20, IERC20)
        returns (bool)
    {
        _accrueRewards(from);
        _accrueRewards(to);

        _moveVotingPower(_delegates[from], _delegates[to], amount);

        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev Lookup a value in a list of (sorted) checkpoints.
     */
    function _checkpointsLookup(Checkpoint[] storage ckpts, uint256 blockNumber) private view returns (uint256) {
        // We run a binary search to look for the earliest checkpoint taken after `blockNumber`.
        //
        // Initially we check if the block is recent to narrow the search range.
        // During the loop, the index of the wanted checkpoint remains in the range [low-1, high).
        // With each iteration, either `low` or `high` is moved towards the middle of the range to maintain the invariant.
        // - If the middle checkpoint is after `blockNumber`, we look in [low, mid)
        // - If the middle checkpoint is before or equal to `blockNumber`, we look in [mid+1, high)
        // Once we reach a single value (when low == high), we've found the right checkpoint at the index high-1, if not
        // out of bounds (in which case we're looking too far in the past and the result is 0).
        // Note that if the latest checkpoint available is exactly for `blockNumber`, we end up with an index that is
        // past the end of the array, so we technically don't find a checkpoint after `blockNumber`, but it works out
        // the same.
        uint256 length = ckpts.length;

        uint256 low = 0;
        uint256 high = length;

        if (length > 5) {
            uint256 mid = length - Math.sqrt(length);
            if (_unsafeAccess(ckpts, mid).fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(ckpts, mid).fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return high == 0 ? 0 : _unsafeAccess(ckpts, high - 1).votes;
    }

    /**
     * @dev Delegate votes from the sender to `delegatee`.
     */
    function delegate(address delegatee) public virtual override {
        _delegate(_msgSender(), delegatee);
    }

    /**
     * @dev Delegates votes from signer to `delegatee`
     */
    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s)
        public
        virtual
        override
    {
        require(block.timestamp <= expiry, "ERC20Votes: signature expired");
        address signer = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(_DELEGATION_TYPEHASH, delegatee, nonce, expiry))), v, r, s
        );
        require(nonce == _useNonce(signer), "ERC20Votes: invalid nonce");
        _delegate(signer, delegatee);
    }

    /**
     * @dev Maximum token supply. Defaults to `type(uint224).max` (2^224^ - 1).
     */
    function _maxSupply() internal view virtual returns (uint224) {
        return type(uint224).max;
    }

    /// @dev Snapshots the totalSupply after it has been increased.
    function _mint(address account, uint256 amount) internal virtual override {
        super._mint(account, amount);

        require(totalSupply() <= _maxSupply(), "ERC20Votes: total supply risks overflowing votes");

        _writeCheckpoint(_totalSupplyCheckpoints, _add, amount);
    }

    function _mintVotingPower(address account, uint256 amount) internal virtual {
        _writeCheckpoint(_totalSupplyCheckpoints, _add, amount);
        _moveVotingPower(address(0), account, amount);
    }

    function _burnVotingPower(address account, uint256 amount) internal virtual {
        _writeCheckpoint(_totalSupplyCheckpoints, _subtract, amount);
        _moveVotingPower(account, address(0), amount);
    }

    /**
     * @dev Snapshots the totalSupply after it has been decreased.
     */
    function _burn(address account, uint256 amount) internal virtual override {
        super._burn(account, amount);

        _writeCheckpoint(_totalSupplyCheckpoints, _subtract, amount);
    }

    /**
     * @dev Change delegation for `delegator` to `delegatee`.
     *
     * Emits events {IVotes-DelegateChanged} and {IVotes-DelegateVotesChanged}.
     */
    function _delegate(address delegator, address delegatee) internal virtual {
        // cash out your rewards
        _accrueRewards(delegator);

        address currentDelegate = delegates(delegator);
        uint256 delegatorBalance = balanceOf(delegator) + _voteRewards[delegator];

        _delegates[delegator] = delegatee;
        DelegationCycle storage cycle = _delegationCycles[delegator];

        // start new delegation cycle for delegatee
        ISPOGGovernor governor = ISPOG(spog).governor();
        uint256 epoch = governor.currentEpoch();
        cycle.startEpoch = epoch;
        cycle.delegateActivity = governor.delegateActivity(delegatee);
        cycle.previousDelegate = currentDelegate;
        cycle.previousDelegateRewardAdjusted = governor.isActive(epoch, currentDelegate);
        cycle.currentDelegateRewardAdjusted = governor.isActive(epoch, delegatee);

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveVotingPower(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveVotingPower(address src, address dst, uint256 amount) private {
        if (src != dst && amount > 0) {
            if (src != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(_checkpoints[src], _subtract, amount);
                emit DelegateVotesChanged(src, oldWeight, newWeight);
            }

            if (dst != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(_checkpoints[dst], _add, amount);
                emit DelegateVotesChanged(dst, oldWeight, newWeight);
            }
        }
    }

    function _writeCheckpoint(
        Checkpoint[] storage ckpts,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) private returns (uint256 oldWeight, uint256 newWeight) {
        uint256 pos = ckpts.length;

        Checkpoint memory oldCkpt = pos == 0 ? Checkpoint(0, 0) : _unsafeAccess(ckpts, pos - 1);

        oldWeight = oldCkpt.votes;
        newWeight = op(oldWeight, delta);

        if (pos > 0 && oldCkpt.fromBlock == block.number) {
            _unsafeAccess(ckpts, pos - 1).votes = SafeCast.toUint224(newWeight);
        } else {
            ckpts.push(Checkpoint({fromBlock: SafeCast.toUint32(block.number), votes: SafeCast.toUint224(newWeight)}));
        }
    }

    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Access an element of the array without performing bounds check. The position is assumed to be within bounds.
     */
    function _unsafeAccess(Checkpoint[] storage ckpts, uint256 pos) private pure returns (Checkpoint storage result) {
        assembly {
            mstore(0, ckpts.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }

    function _accrueRewards(address delegator) internal virtual {
        address currentDelegate = delegates(delegator);
        uint256 delegatorBalance = balanceOf(delegator) + _voteRewards[delegator];

        // calculate rewards for number of active epochs (delegate voted on all proposals in these epochs)
        ISPOGGovernor governor = ISPOG(spog).governor();
        uint256 activeEpochs = governor.delegateActivity(currentDelegate);
        DelegationCycle storage cycle = _delegationCycles[delegator];

        uint256 delta = activeEpochs - cycle.delegateActivity;
        if (!cycle.currentDelegateRewardAdjusted && governor.isActive(cycle.startEpoch, currentDelegate)) {
            cycle.currentDelegateRewardAdjusted = true;
            delta -= 1;
        }
        if (!cycle.previousDelegateRewardAdjusted && governor.isActive(cycle.startEpoch, cycle.previousDelegate)) {
            cycle.previousDelegateRewardAdjusted = true;
            delta += 1;
        }
        if (delta == 0) return;

        uint256 delegatorBalanceWithReward = _compound(delegatorBalance, ISPOG(spog).inflator(), delta);
        uint256 reward = delegatorBalanceWithReward - delegatorBalance;
        _voteRewards[delegator] += reward;

        cycle.delegateActivity = activeEpochs;

        // super._mint(delegator, reward);
        // _burnVotingPower(currentDelegate, reward);
    }

    function claimVoteRewards() external returns (uint256) {
        _accrueRewards(msg.sender);
        uint256 reward = _voteRewards[msg.sender];
        if (reward == 0) return 0;
        // require(reward > 0, "No rewards to claim");

        _voteRewards[msg.sender] = 0;
        _mint(msg.sender, reward);
        /// @dev Voting power of currentDelegate was already updated when vote was casted, no need for double upgrade
        address currentDelegate = delegates(msg.sender);
        _burnVotingPower(currentDelegate, reward);

        // emit VoteRewardClaimed(msg.sender, reward);

        return reward;
    }

    function addVotingPower(address account, uint256 amount) external {
        require(msg.sender == address(ISPOG(spog).governor()), "Caller is not governor");
        _mintVotingPower(account, amount);
    }

    // TODO: primitive implementation for demonstartion purposes only
    function _compound(uint256 principal, uint256 inflator, uint256 epochs) private pure returns (uint256) {
        for (uint256 i; i < epochs;) {
            principal += principal * inflator / 100;
            unchecked {
                ++i;
            }
        }
        return principal;
    }

    /// @notice Restricts minting to address with MINTER_ROLE
    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}

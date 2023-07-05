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
        uint224 amount;
    }

    struct DelegateCheckpoint {
        uint32 fromBlock;
        address delegate;
    }

    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    mapping(address => address) private _delegates;

    mapping(address => Checkpoint[]) private _votesCheckpoints;
    Checkpoint[] private _totalVotesCheckpoints;

    mapping(address => Checkpoint[]) private _balancesCheckpoints;
    Checkpoint[] private _totalSupplyCheckpoints;

    mapping(address => DelegateCheckpoint[]) private _delegatesCheckpoints;

    // owner => current delegation cycle
    // combine together
    mapping(address => uint256) private _voteRewards;
    mapping(address => uint256) private lastEpochRewardsAccrued;

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

    function checkpoints(address account, uint32 pos) public view virtual returns (Checkpoint memory) {
        return _votesCheckpoints[account][pos];
    }

    function numCheckpoints(address account) public view virtual returns (uint32) {
        return SafeCast.toUint32(_votesCheckpoints[account].length);
    }

    function delegates(address account) public view virtual override returns (address) {
        return _delegates[account];
    }

    function getVotes(address account) public view virtual override returns (uint256) {
        uint256 pos = _votesCheckpoints[account].length;
        return pos == 0 ? 0 : _votesCheckpoints[account][pos - 1].amount;
    }

    function getPastVotes(address account, uint256 blockNumber) public view virtual override returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _checkpointsLookup(_votesCheckpoints[account], blockNumber);
    }

    //TODO add override
    function getPastBalance(address account, uint256 blockNumber) public view virtual returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _checkpointsLookup(_votesCheckpoints[account], blockNumber);
    }

    function getPastTotalSupply(uint256 blockNumber) public view virtual override returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _checkpointsLookup(_totalVotesCheckpoints, blockNumber);
    }

    //TODO add override
    function getPastTotalBalanceSupply(uint256 blockNumber) public view virtual returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _checkpointsLookup(_totalSupplyCheckpoints, blockNumber);
    }

    function getPastDelegate(address account, uint256 blockNumber) public view virtual returns (address) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _delegateCheckpointsLookup(_delegatesCheckpoints[account], blockNumber);
    }

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

        return high == 0 ? 0 : _unsafeAccess(ckpts, high - 1).amount;
    }

    function _delegateCheckpointsLookup(DelegateCheckpoint[] storage ckpts, uint256 blockNumber)
        private
        view
        returns (address)
    {
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
            if (_unsafeDelegateAccess(ckpts, mid).fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeDelegateAccess(ckpts, mid).fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return high == 0 ? address(0) : _unsafeDelegateAccess(ckpts, high - 1).delegate;
    }

    function delegate(address delegatee) public virtual override {
        _delegate(_msgSender(), delegatee);
    }

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

    function _maxSupply() internal view virtual returns (uint224) {
        return type(uint224).max;
    }

    function _mint(address account, uint256 amount) internal virtual override {
        super._mint(account, amount);

        require(totalSupply() <= _maxSupply(), "ERC20Votes: total supply risks overflowing votes");

        _mintVotingPower(_delegates[account], amount);

        _moveBalance(address(0), account, amount);
        _writeCheckpoint(_totalSupplyCheckpoints, _add, amount);
    }

    function _burn(address account, uint256 amount) internal virtual override {
        super._burn(account, amount);

        // TODO burn from account
        _burnVotingPower(account, amount);

        _moveBalance(account, address(0), amount);
        _writeCheckpoint(_totalSupplyCheckpoints, _subtract, amount);
    }

    function _moveVotingPower(address src, address dst, uint256 amount) private {
        if (src != dst && amount > 0) {
            if (src != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(_votesCheckpoints[src], _subtract, amount);
                emit DelegateVotesChanged(src, oldWeight, newWeight);
            }

            if (dst != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(_votesCheckpoints[dst], _add, amount);
                emit DelegateVotesChanged(dst, oldWeight, newWeight);
            }
        }
    }

    function _moveBalance(address src, address dst, uint256 amount) private {
        if (src != dst && amount > 0) {
            if (src != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(_balancesCheckpoints[src], _subtract, amount);
                // emit DelegateVotesChanged(src, oldWeight, newWeight);
            }

            if (dst != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(_balancesCheckpoints[dst], _add, amount);
                // emit DelegateVotesChanged(dst, oldWeight, newWeight);
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

        oldWeight = oldCkpt.amount;
        newWeight = op(oldWeight, delta);

        if (pos > 0 && oldCkpt.fromBlock == block.number) {
            _unsafeAccess(ckpts, pos - 1).amount = SafeCast.toUint224(newWeight);
        } else {
            ckpts.push(Checkpoint({fromBlock: SafeCast.toUint32(block.number), amount: SafeCast.toUint224(newWeight)}));
        }
    }

    function _writeDelegateCheckpoint(DelegateCheckpoint[] storage ckpts, address newDelegate) private {
        uint256 pos = ckpts.length;

        DelegateCheckpoint memory oldCkpt =
            pos == 0 ? DelegateCheckpoint(0, address(0)) : _unsafeDelegateAccess(ckpts, pos - 1);

        if (pos > 0 && oldCkpt.fromBlock == block.number) {
            _unsafeDelegateAccess(ckpts, pos - 1).delegate = newDelegate;
        } else {
            ckpts.push(DelegateCheckpoint({fromBlock: SafeCast.toUint32(block.number), delegate: newDelegate}));
        }
    }

    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }

    function _unsafeAccess(Checkpoint[] storage ckpts, uint256 pos) private pure returns (Checkpoint storage result) {
        assembly {
            mstore(0, ckpts.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }

    function _unsafeDelegateAccess(DelegateCheckpoint[] storage ckpts, uint256 pos)
        private
        pure
        returns (DelegateCheckpoint storage result)
    {
        assembly {
            mstore(0, ckpts.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }

    /*//////////////////////////////////////////////////////////////
            INFLATIONARY VOTES UNIQUE TOKEN INTERFACE
    //////////////////////////////////////////////////////////////*/

    function totalVotes() public view virtual returns (uint256) {
        uint256 pos = _totalVotesCheckpoints.length;
        return pos == 0 ? 0 : _totalVotesCheckpoints[pos - 1].amount;
    }

    function getUnclaimedVoteRewards(address account) public view virtual returns (uint256) {
        return _voteRewards[account];
    }

    /// @dev Performs ERC20 transfer with delegation tracking.
    function transfer(address to, uint256 amount) public virtual override(ERC20, IERC20) returns (bool) {
        // cash out rewards
        // _accrueRewards(msg.sender);
        // _accrueRewards(to);

        _moveBalance(msg.sender, to, amount);
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
        // _accrueRewards(from);
        // _accrueRewards(to);

        _moveBalance(from, to, amount);
        _moveVotingPower(_delegates[from], _delegates[to], amount);

        return super.transferFrom(from, to, amount);
    }

    function addVotingPower(address account, uint256 amount) external {
        require(msg.sender == address(ISPOG(spog).governor()), "Caller is not governor");
        _mintVotingPower(account, amount);
    }

    function claimVoteRewards() external returns (uint256) {
        _accrueRewards(msg.sender);

        uint256 reward = _voteRewards[msg.sender];
        if (reward == 0) return 0;

        _voteRewards[msg.sender] = 0;
        _mint(msg.sender, reward);
        /// @dev Voting power of currentDelegate was already updated when vote was casted, no need for double upgrade
        address currentDelegate = delegates(msg.sender);
        // TODO does not account for delayed reward
        // _burnVotingPower(currentDelegate, reward);

        // emit VoteRewardClaimed(msg.sender, reward);

        return reward;
    }

    function _mintVotingPower(address account, uint256 amount) internal virtual {
        _writeCheckpoint(_totalVotesCheckpoints, _add, amount);
        require(totalVotes() <= _maxSupply(), "InflationaryVotes: total voting power overflowing risk");
        _moveVotingPower(address(0), account, amount);
    }

    function _burnVotingPower(address account, uint256 amount) internal virtual {
        _writeCheckpoint(_totalVotesCheckpoints, _subtract, amount);
        _moveVotingPower(account, address(0), amount);
    }

    function _delegate(address delegator, address delegatee) internal virtual {
        _writeDelegateCheckpoint(_delegatesCheckpoints[delegator], delegatee);

        // cash out your rewards
        _accrueRewards(delegator);

        // start new delegation cycle for delegator
        ISPOGGovernor governor = ISPOG(spog).governor();
        uint256 currentEpoch = governor.currentEpoch();
        address currentDelegate = delegates(delegator);
        uint256 delegatorBalance = balanceOf(delegator) + _voteRewards[delegator];

        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveVotingPower(currentDelegate, delegatee, delegatorBalance);
    }

    function _accrueRewards(address delegator) internal virtual {
        // calculate rewards for number of active epochs (delegate voted on all proposals in these epochs)
        ISPOGGovernor governor = ISPOG(spog).governor();
        uint256 currentEpoch = governor.currentEpoch();
        // no rewards are available for epoch 0
        if (currentEpoch == 0) return;

        uint256 reward;
        uint256 startEpoch = lastEpochRewardsAccrued[delegator];
        for (uint256 epoch = startEpoch + 1; epoch <= currentEpoch;) {
            uint256 epochStart = governor.startOf(epoch);
            address epochDelegate = getPastDelegate(delegator, epochStart);
            if (governor.isActive(epoch, epochDelegate)) {
                reward += getPastBalance(delegator, epochStart) * ISPOG(spog).inflator() / 100;
            }
            unchecked {
                ++epoch;
            }
        }

        _voteRewards[delegator] += reward;
        address currentEpochStartDelegate = getPastDelegate(delegator, governor.startOf(currentEpoch));

        // TODO: see if it can be written better
        lastEpochRewardsAccrued[delegator] =
            governor.isActive(currentEpoch, currentEpochStartDelegate) ? currentEpoch : currentEpoch - 1;

        // TODO emit events here
    }

    /// @notice Restricts minting to address with MINTER_ROLE
    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import { IERC6372 } from "./IERC6372.sol";

interface IGovernor is IERC6372 {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );

    event ProposalCanceled(uint256 proposalId);

    event ProposalExecuted(uint256 proposalId);

    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

    // Governors can change their own parameters, like proposal times and the amount of voting power required to
    // create and pass proposals. To make sure that Tally indexes your Governor's parameter changes,
    // implement these event signatures.
    event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator);

    // Needed? Wanted?
    /**
     * @dev Cancel a proposal. A proposal is cancellable by the proposer, but only while it is Pending state, i.e.
     * before the vote starts.
     *
     * Emits a {ProposalCanceled} event.
     */
    // function cancel(
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[] memory calldatas,
    //     bytes32 descriptionHash
    // ) public virtual returns (uint256 proposalId);

    function castVote(uint256 proposalId, uint8 support) external returns (uint256 weight);

    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external returns (uint256 weight);

    /**
     * @dev Execute a successful proposal. This requires the quorum to be reached, the vote to be successful, and the
     * deadline to be reached.
     *
     * Emits a {ProposalExecuted} event.
     *
     * Note: some module can modify the requirements for execution, for example by adding an additional timelock.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256 proposalId);

    /**
     * @dev Create a new proposal. Vote start after a delay specified by {IGovernor-votingDelay} and lasts for a
     * duration specified by {IGovernor-votingPeriod}.
     *
     * Emits a {ProposalCreated} event.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256 proposalId);

    // NOTE: If your OpenZeppelin governor contract uses a Timelock, it will also need this signature.
    // function queue(
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[]   memory calldatas,
    //     bytes32          descriptionHash
    // ) external returns (uint256);

    function COUNTING_MODE() external view returns (string memory countingMode);

    /**
     * @notice module:reputation
     * @dev Voting power of an `account` at a specific `timepoint`.
     *
     * Note: this can be implemented in a number of ways, for example by reading the delegated balance from one (or
     * multiple), {ERC20Votes} tokens.
     */
    function getVotes(address account, uint256 timepoint) external view returns (uint256 weight);

    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256 proposalId);

    // NOTE: Does not seem to be needed by Tally, but is implemented in OpenZeppelin's Governor contract.
    function hasVoted(uint256 proposalId, address account) external view returns (bool hasVoted);

    /**
     * @notice module:core
     * @dev Timepoint at which votes close. If using block number, votes close at the end of this block, so it is
     * possible to cast a vote during this block.
     */
    function proposalDeadline(uint256 proposalId) external view returns (uint256 deadline);

    function proposalProposer(uint256 proposalId) external view returns (address proposer);

    /**
     * @notice module:core
     * @dev Timepoint used to retrieve user's votes and quorum. If using block number (as per Compound's Comp), the
     * snapshot is performed at the end of this block. Hence, voting for this proposal starts at the beginning of the
     * following block.
     */
    function proposalSnapshot(uint256 proposalId) external view returns (uint256 snapshot);

    // function proposalThreshold() external view returns (uint256 proposalThreshold);

    // Tally needs the quorum to calculate if a proposal has passed.
    /**
     * @notice module:user-config
     * @dev Minimum number of cast voted required for a proposal to be successful.
     *
     * NOTE: The `timepoint` parameter corresponds to the snapshot used for counting vote. This allows to scale the
     * quorum depending on values such as the totalSupply of a token at this timepoint (see {ERC20Votes}).
     */
    function quorum(uint256 timepoint) external view returns (uint256 quorum);

    // NOTE: Optionally, Tally also supports the quorumNumerator() and quorumDenominator() functions.
    //       Governors with quorums that are a function of token supply should implement these functions.
    //       If the Governor is missing either quorumNumerator() or quorumDenominator(),
    //       Tally falls back to the quorum() function and assumes that the quorum is fixed.
    // function quorumNumerator() external returns (uint256 quorumNumerator_);
    // function quorumDenominator() external returns (uint256 quorumDenominator_);

    function state(uint256 proposalId) external view returns (ProposalState state);

    // Tally needs to know the voting delay to calculate when voting starts without polling the blockchain.
    /**
     * @notice module:user-config
     * @dev Delay, between the proposal is created and the vote starts. The unit this duration is expressed in depends
     * on the clock (see EIP-6372) this contract uses.
     *
     * This can be increased to leave time for users to buy voting power, or delegate it, before the voting of a
     * proposal starts.
     */
    function votingDelay() external view returns (uint256 votingDelay);

    // Tally needs to know the voting period to calculate when a proposal finishes voting without polling the blockchain.
    /**
     * @notice module:user-config
     * @dev Delay between the vote start and vote end. The unit this duration is expressed in depends on the clock
     * (see EIP-6372) this contract uses.
     *
     * NOTE: The {votingDelay} can delay the start of the vote. This must be considered when setting the voting
     * duration compared to the voting delay.
     */
    function votingPeriod() external view returns (uint256 votingPeriod);
}

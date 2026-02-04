// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract TokenDAO  is
    GovernorSettingsUpgradeable,    
    GovernorStorageUpgradeable,
    GovernorVotesQuorumFractionUpgradeable
{

    enum VoteType {
        Against,
        For,
        Abstain,
        Deliberate
    }

    struct ProposalVote {
        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;
        mapping(address voter => bool) hasVoted;
    }

    mapping(uint256 proposalId => ProposalVote) private _proposalVotes;

    constructor() {
        //_disableInitializers();
    }

    function initialize(
        string memory name,
        IVotes token,
        uint256 threshold,
        uint32 votingPeriod_
    ) external initializer {
        __Governor_init(name);
        __GovernorSettings_init(0, votingPeriod_, threshold);
        __GovernorVotes_init(token);
        __GovernorVotesQuorumFraction_init(5100);
        __GovernorStorage_init();

    }

    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE()
        public
        pure
        virtual
        override
        returns (string memory)
    {
        return "support= bravo&quorum=for,abstain";
    }

    function hasVoted(
        uint256 proposalId,
        address account
    ) public view virtual returns (bool) {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    function proposalVotes(
        uint256 proposalId
    )
        public
        view
        virtual
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
    {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (
            proposalVote.againstVotes,
            proposalVote.forVotes,
            proposalVote.abstainVotes
        );
    }

    function _quorumReached(
        uint256 proposalId
    ) internal view virtual override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        return
            quorum(proposalSnapshot(proposalId)) <=
            proposalVote.forVotes + proposalVote.abstainVotes;
    }


    function _voteSucceeded(
        uint256 proposalId
    ) internal view virtual override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        return proposalVote.forVotes > proposalVote.againstVotes;
    }

    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight,
        bytes memory // params
    ) internal virtual override returns (uint256) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        // Allow user to cast vote with opinion and type "Deliberate" to signal that they are not voting
        if (support == uint8(VoteType.Deliberate)) {
            return 0;
        }

        if (proposalVote.hasVoted[account]) {
            revert GovernorAlreadyCastVote(account);
        }

        proposalVote.hasVoted[account] = true;

        if (support == uint8(VoteType.Against)) {
            proposalVote.againstVotes += weight;
        } else if (support == uint8(VoteType.For)) {
            proposalVote.forVotes += weight;
        } else if (support == uint8(VoteType.Abstain)) {
            proposalVote.abstainVotes += weight;
        } else {
            revert GovernorInvalidVoteType();
        }
        return weight;
    }

    function quorumDenominator() public pure override returns (uint256) {
        return 10000;
    }

    function state(
        uint256 proposalId
    ) public view override(GovernorUpgradeable) returns (ProposalState) {
        // Allow early execution when reached 100% for votes
        ProposalState currentState = super.state(proposalId);
        if (currentState == ProposalState.Active) {
            (, uint256 forVotes, ) = proposalVotes(proposalId);
            if (
                forVotes ==
                token().getPastTotalSupply(proposalSnapshot(proposalId))
            ) {
                return ProposalState.Succeeded;
            }
        }
        return currentState;
    }

    function _tallyUpdated(uint256 proposalId) internal virtual override {
        _tryAutoExecute(proposalId);
    }

    function _tryAutoExecute(uint256 proposalId) internal {
        (, uint256 forVotes, ) = proposalVotes(proposalId);
        if (
            forVotes == token().getPastTotalSupply(proposalSnapshot(proposalId))
        ) {
            execute(proposalId);
        }
    }

    function proposalThreshold()
        public
        view
        override (GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposer
    )
        internal
        override(GovernorUpgradeable, GovernorStorageUpgradeable)
        returns (uint256)
    {
        return
            super._propose(targets, values, calldatas, description, proposer);
    }
}
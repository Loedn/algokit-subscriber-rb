# frozen_string_literal: true

module Algokit
  module Subscriber
    module Models
      # Represents a block from the Algorand blockchain
      #
      # Contains block metadata including round number, timestamp, transactions,
      # rewards, and other consensus information.
      class Block
        attr_reader :round, :timestamp, :genesis_id, :genesis_hash,
                    :previous_block_hash, :seed, :transactions_root,
                    :transactions_root_sha256, :txn_counter, :rewards,
                    :upgrade_state, :upgrade_vote, :state_proof_tracking,
                    :participation_updates, :proposer

        # @param data [Hash] Raw block data from algod API
        def initialize(data)
          block = data["block"] || data

          @round = block["rnd"]
          @timestamp = block["ts"]
          @genesis_id = block["gen"]
          @genesis_hash = block["gh"]
          @previous_block_hash = block["prev"]
          @seed = block["seed"]
          @transactions_root = block["txn"]
          @transactions_root_sha256 = block["txn256"]
          @txn_counter = block["tc"]
          @proposer = block["proposer"]

          # Rewards information
          @rewards = parse_rewards(block["rwd"]) if block["rwd"]

          # Upgrade information
          @upgrade_state = parse_upgrade_state(block["upgradeState"]) if block["upgradeState"]
          @upgrade_vote = parse_upgrade_vote(block["upgradeVote"]) if block["upgradeVote"]

          # State proof tracking
          @state_proof_tracking = parse_state_proof_tracking(block["spt"]) if block["spt"]

          # Participation updates
          return unless block["partupdrmv"] || block["partupabs"]

          @participation_updates = parse_participation_updates(block["partupdrmv"],
                                                               block["partupabs"])
        end

        # Convert to hash representation
        # @return [Hash]
        def to_h
          {
            round: @round,
            timestamp: @timestamp,
            genesis_id: @genesis_id,
            genesis_hash: @genesis_hash,
            previous_block_hash: @previous_block_hash,
            seed: @seed,
            transactions_root: @transactions_root,
            transactions_root_sha256: @transactions_root_sha256,
            txn_counter: @txn_counter,
            proposer: @proposer,
            rewards: @rewards,
            upgrade_state: @upgrade_state,
            upgrade_vote: @upgrade_vote,
            state_proof_tracking: @state_proof_tracking,
            participation_updates: @participation_updates
          }.compact
        end

        private

        def parse_rewards(data)
          {
            fee_sink: data["FeeSink"],
            rewards_calculation_round: data["RewardsRecalculationRound"],
            rewards_level: data["RewardsLevel"],
            rewards_pool: data["RewardsPool"],
            rewards_rate: data["RewardsRate"],
            rewards_residue: data["RewardsResidue"]
          }
        end

        def parse_upgrade_state(data)
          {
            current_protocol: data["currentProtocol"],
            next_protocol: data["nextProtocol"],
            next_protocol_approvals: data["nextProtocolApprovals"],
            next_protocol_vote_before: data["nextProtocolVoteBefore"],
            next_protocol_switch_on: data["nextProtocolSwitchOn"]
          }.compact
        end

        def parse_upgrade_vote(data)
          {
            upgrade_approve: data["upgradeApprove"],
            upgrade_delay: data["upgradeDelay"],
            upgrade_propose: data["upgradePropose"]
          }.compact
        end

        def parse_state_proof_tracking(data)
          return [] unless data.is_a?(Array)

          data.map do |tracking|
            {
              next_round: tracking["nextRound"],
              online_total_weight: tracking["onlineTotalWeight"],
              type: tracking["type"],
              voters_commitment: tracking["votersCommitment"]
            }.compact
          end
        end

        def parse_participation_updates(expired, absent)
          {
            expired_participation_accounts: expired,
            absent_participation_accounts: absent
          }.compact
        end
      end
    end
  end
end

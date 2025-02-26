module debate_v2::ai_debate_v2 {
    use std::signer;
    use std::string::String;
    use std::vector;
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::event;

    // Error codes
    const ENO_DEBATE: u64 = 1;         // Debate does not exist
    const EDEBATE_ENDED: u64 = 2;      // Debate has already ended
    const EINVALID_AMOUNT: u64 = 3;    // Invalid betting amount
    const ENOT_CREATOR: u64 = 4;       // Not the creator of the debate
    const EDEBATE_NOT_ENDED: u64 = 5;  // Debate has not ended yet
    const EALREADY_CLAIMED: u64 = 6;   // Rewards already claimed
    const EDEBATE_HAS_BETS: u64 = 7;  // Debate has active bets
    const EDEBATE_ACTIVE: u64 = 8;    // Debate is still active

    // Constants for AI selection
    const AI_A: u8 = 1;
    const AI_B: u8 = 2;

    struct AIAgent has store, copy, drop {
        name: String,
        character: String,
        address: address
    }

    // Main debate structure
    struct Debate has key, store, copy, drop {
        id: u64,
        name: String,
        topic: String,
        creator: address,
        ai_a: AIAgent,
        ai_b: AIAgent,
        total_pool: u64,
        ai_a_pool: u64,
        ai_b_pool: u64,
        winner: u8,
        is_finished: bool
    }

    // Betting information structure
    struct BetInfo has key, store, copy {
        game_id: u64,
        amount: u64,
        choice: u8,
        claimed: bool
    }

    // Store for all debates
    struct DebateStore has key {
        debates: vector<Debate>,
        debate_counter: u64,
        bet_events: event::EventHandle<BetEvent>,
    }

    // Event for betting
    struct BetEvent has drop, store {
        debate_id: u64,
        bettor: address,
        amount: u64,
        choice: u8
    }

    // Initialize the debate store
    public entry fun initialize(account: &signer) {
        let store = DebateStore {
            debates: vector::empty(),
            debate_counter: 0,
            bet_events: account::new_event_handle<BetEvent>(account),
        };
        move_to(account, store);
    }

    // Create a new debate
    public entry fun create_debate(
        creator: &signer,
        name: String,
        topic: String,
        ai_a_name: String,
        ai_a_character: String,
        ai_a_address: address,
        ai_b_name: String,
        ai_b_character: String,
        ai_b_address: address
    ) acquires DebateStore {
        let store = borrow_global_mut<DebateStore>(@debate_v2);
        
        let debate = Debate {
            id: store.debate_counter + 1,
            name,
            topic,
            creator: signer::address_of(creator),
            ai_a: AIAgent {
                name: ai_a_name,
                character: ai_a_character,
                address: ai_a_address
            },
            ai_b: AIAgent {
                name: ai_b_name,
                character: ai_b_character,
                address: ai_b_address
            },
            total_pool: 0,
            ai_a_pool: 0,
            ai_b_pool: 0,
            winner: 0,
            is_finished: false
        };

        vector::push_back(&mut store.debates, debate);
        store.debate_counter = store.debate_counter + 1;
    }

    // Place a bet on a debate
    public entry fun place_bet(
        bettor: &signer,
        debate_id: u64,
        amount: u64,
        choice: u8
    ) acquires DebateStore {
        let store = borrow_global_mut<DebateStore>(@debate_v2);
        let debate = vector::borrow_mut(&mut store.debates, debate_id - 1);
        
        assert!(!debate.is_finished, EDEBATE_ENDED);
        assert!(timestamp::now_seconds() < debate.end_time, EDEBATE_ENDED);
        assert!(choice == AI_A || choice == AI_B, EINVALID_AMOUNT);

        if (choice == AI_A) {
            debate.ai_a_pool = debate.ai_a_pool + amount;
        } else {
            debate.ai_b_pool = debate.ai_b_pool + amount;
        };
        debate.total_pool = debate.total_pool + amount;

        let bet_info = BetInfo {
            game_id: debate_id,
            amount,
            choice,
            claimed: false
        };
        move_to(bettor, bet_info);

        event::emit_event(&mut store.bet_events, BetEvent {
            debate_id,
            bettor: signer::address_of(bettor),
            amount,
            choice
        });
    }

    // Finalize a debate with winner
    public entry fun finalize_debate(
        creator: &signer,
        debate_id: u64,
        winner: u8
    ) acquires DebateStore {
        let store = borrow_global_mut<DebateStore>(@debate_v2);
        let debate = vector::borrow_mut(&mut store.debates, debate_id - 1);
        
        assert!(signer::address_of(creator) == debate.creator, ENOT_CREATOR);
        assert!(!debate.is_finished, EDEBATE_ENDED);
        
        debate.winner = winner;
        debate.is_finished = true;
    }

    // Withdraw winnings
    public entry fun withdraw_winnings(
        user: &signer,
        debate_id: u64
    ) acquires DebateStore, BetInfo {
        let store = borrow_global<DebateStore>(@debate_v2);
        let debate = vector::borrow(&store.debates, debate_id - 1);
        
        assert!(debate.is_finished, EDEBATE_NOT_ENDED);
        
        let user_addr = signer::address_of(user);
        let bet_info = borrow_global_mut<BetInfo>(user_addr);
        
        assert!(!bet_info.claimed, EALREADY_CLAIMED);
        assert!(bet_info.choice == debate.winner, ENO_DEBATE);
        
        let winning_pool = if (debate.winner == AI_A) {
            debate.ai_a_pool
        } else {
            debate.ai_b_pool
        };
        
        let reward = (bet_info.amount * debate.total_pool) / winning_pool;
        bet_info.claimed = true;
        _ = reward;
    }

    // Delete a debate (for testing purposes)
    public entry fun delete_debate(
        creator: &signer,
        debate_id: u64
    ) acquires DebateStore {
        let store = borrow_global_mut<DebateStore>(@debate_v2);
        
        let debate = vector::borrow(&store.debates, debate_id - 1);
        assert!(signer::address_of(creator) == debate.creator, ENOT_CREATOR);
        
        vector::remove(&mut store.debates, debate_id - 1);
    }

    // View function to get debate information
    #[view]
    public fun get_debate(debate_id: u64): Debate acquires DebateStore {
        let store = borrow_global<DebateStore>(@debate_v2);
        *vector::borrow(&store.debates, debate_id - 1)
    }

    // View function to get bet information
    #[view]
    public fun get_bet_info(user_addr: address): BetInfo acquires BetInfo {
        *borrow_global<BetInfo>(user_addr)
    }

    // View function to get debate pool information
    #[view]
    public fun get_debate_pool(debate_id: u64): (u64, u64, u64) acquires DebateStore {
        let store = borrow_global<DebateStore>(@debate_v2);
        let debate = vector::borrow(&store.debates, debate_id - 1);
        (debate.total_pool, debate.ai_a_pool, debate.ai_b_pool)
    }
}
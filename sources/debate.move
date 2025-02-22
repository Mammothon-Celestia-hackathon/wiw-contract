module debate::ai_debate {
    use std::signer;
    use std::string::String;
    use std::vector;
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::event;

    // Error codes
    const ENO_DEBATE: u64 = 1;
    const EDEBATE_ENDED: u64 = 2;
    const EINVALID_AMOUNT: u64 = 3;
    const ENOT_CREATOR: u64 = 4;
    const EDEBATE_NOT_ENDED: u64 = 5;
    const EALREADY_CLAIMED: u64 = 6;

    // Constants for AI selection
    const AI_A: u8 = 1;
    const AI_B: u8 = 2;

    struct Debate has key, store {
        id: u64,
        creator: address,
        topic: String,
        ai_a: String,
        ai_b: String,
        total_pool: u64,
        ai_a_pool: u64,
        ai_b_pool: u64,
        end_time: u64,
        winner: u8,
        is_finished: bool
    }

    struct BetInfo has key, store {
        debate_id: u64,
        amount: u64,
        choice: u8,
        claimed: bool
    }

    struct DebateStore has key {
        debates: vector<Debate>,
        debate_counter: u64,
        bet_events: event::EventHandle<BetEvent>,
    }

    struct BetEvent has drop, store {
        debate_id: u64,
        bettor: address,
        amount: u64,
        choice: u8
    }

    public entry fun initialize(account: &signer) {
        let store = DebateStore {
            debates: vector::empty(),
            debate_counter: 0,
            bet_events: account::new_event_handle<BetEvent>(account),
        };
        move_to(account, store);
    }

    public entry fun create_debate(
        creator: &signer,
        topic: String,
        ai_a: String,
        ai_b: String,
        duration: u64
    ) acquires DebateStore {
        let creator_addr = signer::address_of(creator);
        let store = borrow_global_mut<DebateStore>(@debate);
        
        let debate = Debate {
            id: store.debate_counter + 1,
            creator: creator_addr,
            topic,
            ai_a,
            ai_b,
            total_pool: 0,
            ai_a_pool: 0,
            ai_b_pool: 0,
            end_time: timestamp::now_seconds() + duration,
            winner: 0,
            is_finished: false
        };

        vector::push_back(&mut store.debates, debate);
        store.debate_counter = store.debate_counter + 1;
    }

    public entry fun place_bet(
        bettor: &signer,
        debate_id: u64,
        amount: u64,
        choice: u8
    ) acquires DebateStore {
        let store = borrow_global_mut<DebateStore>(@debate);
        let debate = vector::borrow_mut(&mut store.debates, debate_id - 1);
        
        assert!(!debate.is_finished, EDEBATE_ENDED);
        assert!(timestamp::now_seconds() < debate.end_time, EDEBATE_ENDED);
        assert!(choice == AI_A || choice == AI_B, EINVALID_AMOUNT);

        let bettor_addr = signer::address_of(bettor);
        
        if (choice == AI_A) {
            debate.ai_a_pool = debate.ai_a_pool + amount;
        } else {
            debate.ai_b_pool = debate.ai_b_pool + amount;
        };
        debate.total_pool = debate.total_pool + amount;

        // Save betting information
        let bet_info = BetInfo {
            debate_id,
            amount,
            choice,
            claimed: false
        };
        move_to(bettor, bet_info);

        // Emit event
        event::emit_event(&mut store.bet_events, BetEvent {
            debate_id,
            bettor: bettor_addr,
            amount,
            choice
        });
    }

    public entry fun finalize_debate(
        creator: &signer,
        debate_id: u64,
        winner: u8
    ) acquires DebateStore {
        let store = borrow_global_mut<DebateStore>(@debate);
        let debate = vector::borrow_mut(&mut store.debates, debate_id - 1);
        
        assert!(signer::address_of(creator) == debate.creator, ENOT_CREATOR);
        assert!(!debate.is_finished, EDEBATE_ENDED);
        assert!(timestamp::now_seconds() >= debate.end_time, EDEBATE_NOT_ENDED);
        
        debate.winner = winner;
        debate.is_finished = true;
    }

    public entry fun withdraw_winnings(
        user: &signer,
        debate_id: u64
    ) acquires DebateStore, BetInfo {
        let store = borrow_global_mut<DebateStore>(@debate);
        let debate = vector::borrow(&store.debates, debate_id - 1);
        
        assert!(debate.is_finished, EDEBATE_NOT_ENDED);
        
        let user_addr = signer::address_of(user);
        let bet_info = borrow_global_mut<BetInfo>(user_addr);
        
        assert!(!bet_info.claimed, EALREADY_CLAIMED);
        assert!(bet_info.debate_id == debate_id, ENO_DEBATE);
        
        if (bet_info.choice == debate.winner) {
            let winning_pool = if (debate.winner == AI_A) {
                debate.ai_a_pool
            } else {
                debate.ai_b_pool
            };
            
            let _share = (bet_info.amount * debate.total_pool) / winning_pool;
            // TODO: Implement actual token transfer logic
            bet_info.claimed = true;
        };
    }
} 
module solve::solve {
    use game::adventure;
    use game::hero::{Self, Hero};
    use game::inventory;
    use game::inventory::TreasuryBox;

    use sui::bcs::{Self, BCS};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object;

    use std::hash;
    use std::vector;
    const ERR_HIGH_ARG_GREATER_THAN_LOW_ARG: u64 = 101;

    public entry fun solve(box: TreasuryBox, ctx: &mut TxContext) {
        // prepare
        let ctx_bytes = bcs::to_bytes(ctx);
        let prepared: BCS = bcs::new(ctx_bytes);
        let (_, _, _, ids_created) = (
            bcs::peel_address(&mut prepared), 
            bcs::peel_vec_u8(&mut prepared),
            bcs::peel_u64(&mut prepared),
            bcs::peel_u64(&mut prepared),
        );

        // try 100 runs until we get rand == 0
        let my_rand = my_rand_u64_range(0, 100, ids_created, ctx);
        let runs = 0;
        while ( runs < 1000 && my_rand != 0 ) {
            let uid = object::new(ctx);
            object::delete(uid);
            runs = runs + 1;
            my_rand = my_rand_u64_range(0, 100, ids_created + runs, ctx);
        };

        // get_flag or send the box back to caller
        if ( my_rand == 0 ) {
            inventory::get_flag(box, ctx);
        } else {
            transfer::transfer(box, tx_context::sender(ctx));
        }
    }

    public entry fun get_box(hero: &mut Hero, ctx: &mut TxContext) {
        while (hero::experience(hero) < 100) {
            adventure::slay_boar(hero, ctx);
        };

        hero::level_up(hero);

        while (hero::stamina(hero) >= 2) {
            adventure::slay_boar_king(hero, ctx);
        };
    }
            
    //native fun derive_id(tx_hash: vector<u8>, ids_created: u64): address;
    fun derive_id(tx_hash: vector<u8>, ids_created: u64): vector<u8> {
        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, tx_hash);
        vector::append<u8>(&mut info, vector[(ids_created as u8), 0, 0, 0, 0, 0, 0, 0]);
        let hash: vector<u8> = hash::sha3_256(info);
        let length = vector::length(&mut hash);
        while ( length > 20 ) {
            vector::remove(&mut hash, length-1);
            length = length - 1;
        };
        hash
    }

    fun my_new_object(ids_created: u64, ctx: &mut TxContext): vector<u8> {
        let ctx_bytes = bcs::to_bytes(ctx);
        let prepared: BCS = bcs::new(ctx_bytes);
        let (_, tx_hash) = (
            bcs::peel_address(&mut prepared), 
            bcs::peel_vec_u8(&mut prepared),
        );
        let id = derive_id(tx_hash, ids_created);
        id
    }

    fun seed(id: u64, ctx: &mut TxContext): vector<u8> {
        let ctx_bytes = bcs::to_bytes(ctx);
        let uid_bytes: vector<u8> = my_new_object(id, ctx) ;

        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, ctx_bytes);
        vector::append<u8>(&mut info, uid_bytes);

        let hash: vector<u8> = hash::sha3_256(info);
        hash
    }

    fun bytes_to_u64(bytes: vector<u8>): u64 {
        let value = 0u64;
        let i = 0u64;
        while (i < 8) {
            value = value | ((*vector::borrow(&bytes, i) as u64) << ((8 * (7 - i)) as u8));
            i = i + 1;
        };
        return value
    }

    /// Generate a random u64
    fun rand_u64_with_seed(_seed: vector<u8>): u64 {
        bytes_to_u64(_seed)
    }

    /// Generate a random integer range in [low, high).
    fun rand_u64_range_with_seed(_seed: vector<u8>, low: u64, high: u64): u64 {
        assert!(high > low, ERR_HIGH_ARG_GREATER_THAN_LOW_ARG);
        let value = rand_u64_with_seed(_seed);
        (value % (high - low)) + low
    }

    /// Generate a random integer range in [low, high).
    fun my_rand_u64_range(low: u64, high: u64, id: u64, ctx: &mut TxContext): u64 {
        rand_u64_range_with_seed(seed(id, ctx), low, high)
    }
}

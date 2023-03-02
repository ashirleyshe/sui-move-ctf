module solve::solve {
    use sui::tx_context::TxContext;
    use game::inventory::{TreasuryBox};
    use game::adventure;
    use game::hero::Hero;
    use game::hero;
    use ctf::random;
    // use std::debug;
    use sui::event;
    use sui::object;
    use sui::bcs;
    use std::hash;
    use std::vector;
    // use sui::tx_context::derive_id;

    struct Eventsolve {}

    struct Event<phantom T> has copy, drop {
        d100: u64,
        ids: u64,
    }
    struct Eventid<phantom T> has copy, drop {
        cnt: u64,
        ids: u64,
    }
    struct Log has copy, drop{
        uid_bytes: vector<u8>,
        
    }

    struct LogSeed has copy, drop{
        uid_bytes: vector<u8>,
        
    }

    struct UID has store, drop {
        id: ID,
    }

    struct ID has copy, drop, store {
        // We use `address` instead of `vector<u8>` here because `address` has a more
        // compact serialization. `address` is serialized as a BCS fixed-length sequence,
        // which saves us the length prefix we would pay for if this were `vector<u8>`.
        // See https://github.com/diem/bcs#fixed-and-variable-length-sequences.
        bytes: address
    }

    fun derive(tx_hash: vector<u8>, ids_created: u64): vector<u8> {

        let id: vector<u8> = vector::empty<u8>();
        
        let b1: u8 = (((ids_created >> 56) & 0xff) as u8);
        let b2: u8 = (((ids_created >> 48) & 0xff) as u8);
        let b3: u8 = (((ids_created >> 40) & 0xff) as u8);
        let b4: u8 = (((ids_created >> 32) & 0xff) as u8);
        let b5: u8 = (((ids_created >> 24) & 0xff) as u8);
        let b6: u8 = (((ids_created >> 16) & 0xff) as u8);
        let b7: u8 = (((ids_created >> 8) & 0xff) as u8);
        let b8: u8 = ((ids_created & 0xff) as u8);
        
        vector::push_back<u8>(&mut id, b8);
        vector::push_back<u8>(&mut id, b7);
        vector::push_back<u8>(&mut id, b6);
        vector::push_back<u8>(&mut id, b5);
        vector::push_back<u8>(&mut id, b4);
        vector::push_back<u8>(&mut id, b3);
        vector::push_back<u8>(&mut id, b2);
        vector::push_back<u8>(&mut id, b1);

        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, tx_hash);
        vector::append<u8>(&mut info, id);
        let hash: vector<u8> = hash::sha3_256(info);
        // todo turncate 20 bytes

        return hash
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

    fun rand_u64_with_seed(_seed: vector<u8>): u64 {
        bytes_to_u64(_seed)
    }

    fun rand_u64_range_with_seed(_seed: vector<u8>, low: u64, high: u64): u64 {
        let value = rand_u64_with_seed(_seed);
        (value % (high - low)) + low
    }

    public fun uid_to_bytes(uid: &UID): vector<u8> {
        bcs::to_bytes(&uid.id.bytes)
    }

    public entry fun level_up(hero: &mut Hero, ctx: &mut TxContext) {
        while (hero::experience(hero) < 100) {
            adventure::slay_boar(hero, ctx);
        };

        hero::level_up(hero);

        while (hero::stamina(hero) > 2) {
            adventure::slay_boar_king(hero, ctx);
        };
        
    }

    public(friend) fun new_object(ids: u64, ctx: &mut TxContext): vector<u8> {
        let ctx_bytes = bcs::to_bytes(ctx);
        let prepared = bcs::new(ctx_bytes);
        let (_, tx_hash, _, ids_created) = (
            bcs::peel_address(&mut prepared),
            bcs::peel_vec_u8(&mut prepared),
            bcs::peel_u64(&mut prepared),
            bcs::peel_u64(&mut prepared),
        );
        //should return 20 bytes
        let id_tmp = derive(tx_hash, ids_created);
        let i = 0;
        let id: vector<u8> = vector::empty<u8>();
        
        while (i < 20) {
            let tmp = *vector::borrow(&mut id_tmp, i);
            i = i + 1;
            vector::push_back<u8>(&mut id, tmp);
        };
        // ids_created = ids_created + 1;
        id
    }

    fun seed(ids: u64, ctx: &mut TxContext): vector<u8> {
        let ctx_bytes = bcs::to_bytes(ctx);
        // let uid = new(ids, ctx);
        let uid_bytes: vector<u8> = new_object(ids, ctx);
        // object::delete(uid);
        event::emit(LogSeed {uid_bytes: uid_bytes});


        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, ctx_bytes);
        vector::append<u8>(&mut info, uid_bytes);

        let hash: vector<u8> = hash::sha3_256(info);
        hash
    }


    public entry fun solve(box: TreasuryBox, ctx: &mut TxContext) {
        let cnt = 0;
        let ids = 0;
        loop{
            let d100 = rand_u64_range_with_seed(seed(ids, ctx), 0, 100);
            if (d100 == 0) {
                game::inventory::get_flag(box, ctx);
                break
            }; 

            let uid = object::new(ctx);
            let uid_bytes: vector<u8> = object::uid_to_bytes(&uid);
            object::delete(uid);
            event::emit(Log {uid_bytes: uid_bytes});
            cnt = cnt + 1; 
            ids = ids + 1;      
        };
        event::emit(Eventid<Eventsolve> {
            cnt: cnt,
            ids: ids,
        });
    }
}
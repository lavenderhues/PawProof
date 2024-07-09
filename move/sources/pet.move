#[allow(implicit_const_copy, unused_function, unused_variable, unused_mut_parameter, unused_const)]
module deployer::pet {
    use sui::url::{Self, Url};
    use std::string::{Self, String};
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::vector;
    use sui::address;
    use sui::table::{Self, Table};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    //use std::debug;

    use deployer::role::{Self, Roles};

    #[test_only]
    use sui::test_scenario;
    #[test_only]
    use sui::test_utils::assert_eq;

    //==============================================================================================
    // Constants
    //==============================================================================================
    const PRICE: u64 = 1000000000; //1SUI

    //==============================================================================================
    // Error codes
    //==============================================================================================
    /// Insufficient funds
    const ERROR_INSUFFICIENT_FUNDS: u64 = 1;
    const ERROR_SIGNER_NOT_APPROVED_ADOPTER: u64 = 2;
    const ERROR_SIGNER_NOT_VET: u64 = 3;
    const ERROR_SIGNER_NOT_ADMIN_OR_OPERATOR: u64 = 4;
    const ERROR_NOT_AVAILABLE_FOR_ADOPTION: u64 = 5;
    const ERROR_NOT_ADOPTED_YET: u64 = 6;

    //==============================================================================================
    // Structs 
    //==============================================================================================
    struct State has key {
        id: UID,
        //no of minted nft from this contract collection
        minted: u64,
        // list of pets waiting for adoption
        adoption: vector<ID>
    }

    struct PetPassport has key {
        id: UID,
        /// Name for the pet
        name: String,
        /// species, breed, color
        description: String,
        // photo
        url: Url,
        royalty_numerator: u64,
        // <name, species, breed, gender, dob, color/markings>
        pet_info: vector<String>,
        // <name, contact details, address>
        owner_info: vector<String>,
        // <microchip number, date of chipping, location of microchip>
        microchip_info: vector<String>,
        // each table: <date of vaccination, vaccination ref number, date valid from and expiry date, cert image uri, veterinarian signature>
        vaccination_rec: vector<Table<String,String>>,
        // each record <date&time of clinical report, string of clinical report>
        clinical_rec: vector<Table<String,String>>,
    }

    //for those waiting for adoption
    struct AdoptionPet has key {
        id: UID,
        // photo
        url: String,
        royalty_numerator: u64,
        // <name, species, breed, gender, dob, color/markings>
        pet_info: vector<String>,
        // <microchip number, date of chipping, location of microchip>
        microchip_info: vector<String>,
        adopted: bool
    }

    //==============================================================================================
    // Event Structs 
    //==============================================================================================

    struct PassportCreated has copy, drop {
        // The Object ID of the NFT
        object_id: ID,
        // The owner of the NFT
        owner: address,
        // The name of the NFT
        name: String
    }

    //==============================================================================================
    // Init
    //==============================================================================================

    fun init(ctx: &mut TxContext) {
        transfer::share_object(State{id: object::new(ctx), minted: 0, adoption: vector::empty()});
    }

    //==============================================================================================
    // Entry Functions 
    //==============================================================================================

    /// Create a new nft
    public entry fun mint_passport(
        // <name, species, breed, gender, dob, color/markings>
        pet_info: String,
        // photo
        url: String,
        // <name, contact details>
        owner_info: String,
        receiver: address,
        // <microchip number, date of chipping, location of microchip>
        microchip_info: String,
        payment: Coin<SUI>, 
        state: &mut State,
        ctx: &mut TxContext
    ) {
        let (pet_info_vector, owner_info_vector, microchip_info_vector) = (
            create_pet_passport_vector(pet_info),
            create_pet_passport_vector(owner_info),
            create_pet_passport_vector(microchip_info),
        );
        vector::push_back(&mut owner_info_vector, address::to_string(receiver));
        mint_passport_internal(
            url,
            pet_info_vector,
            owner_info_vector,
            microchip_info_vector,
            receiver,
            payment, 
            state,
            ctx
        );
    }

    /// Create a new nft
    public entry fun list_adoption(
        // <name, species, breed, gender, dob, color/markings>
        pet_info: String,
        // photo
        url: String,
        // <microchip number, date of chipping, location of microchip>
        microchip_info: String,
        state: &mut State,
        ctx: &mut TxContext
    ) {
        let uid = object::new(ctx);
        let id = sui::object::uid_to_inner(&uid);
        let adoption = AdoptionPet{
            id: uid,
            url,
            royalty_numerator: 5,
            pet_info: create_pet_passport_vector(pet_info),
            microchip_info: create_pet_passport_vector(microchip_info),
            adopted: false
        };
        transfer::share_object(adoption);
        vector::push_back(&mut state.adoption, id);
    }

    /// Transfer `nft` to `recipient`
    public entry fun transfer(
        nft: PetPassport, recipient: address, _: &mut TxContext
    ) {
        transfer::transfer(nft, recipient)
    }

    /// Vet adds vaccnication record
    public entry fun add_vac(
        nft: &mut PetPassport,
        //<date of vaccination, vaccination ref number, date valid from and expiry date, cert image uri, veterinarian signature>
        //<vac_date, vac_ref_no, date_valid_from, expiry_date, cert_image_uri, vet_sign>
        vac_date: String,
        vac_ref_no: String,
        date_valid_from: String,
        expiry_date: String,
        cert_image_uri: String,
        roles: &mut Roles,
        ctx: &mut TxContext  
    ){
        let sender = tx_context::sender(ctx);
        assert_vet(sender, roles);
        let new_vac_rec = table::new<String, String>(ctx);
        table::add(&mut new_vac_rec, string::utf8(b"vac_date"), vac_date);
        table::add(&mut new_vac_rec, string::utf8(b"vac_ref_no"), vac_ref_no);
        table::add(&mut new_vac_rec, string::utf8(b"date_valid_from"), date_valid_from);
        table::add(&mut new_vac_rec, string::utf8(b"expiry_date"), expiry_date);
        table::add(&mut new_vac_rec, string::utf8(b"cert_image_uri"), cert_image_uri);
        table::add(&mut new_vac_rec, string::utf8(b"vet_sign"), address::to_string(sender));
        vector::push_back(&mut nft.vaccination_rec, new_vac_rec);
    }

    /// Vet adds clinic record
    public entry fun add_clinical_rec(
        nft: &mut PetPassport,
        date_time: String, //date and time of report
        clinical_report: String,
        roles: &mut Roles,
        ctx: &mut TxContext  
    ){
        let sender = tx_context::sender(ctx);
        assert_vet(sender, roles);
        let new_clinical_rec = table::new<String, String>(ctx);
        table::add(&mut new_clinical_rec, date_time, clinical_report);
        vector::push_back(&mut nft.clinical_rec, new_clinical_rec);
    }

    /// user adopts a pet
    public entry fun adopt(
        pet: AdoptionPet,
        // <name, contact details>
        owner_info: String,
        payment: Coin<SUI>, 
        roles: &mut Roles,
        state: &mut State,
        ctx: &mut TxContext  
    ){
        let pet_id = sui::object::uid_to_inner(&pet.id);
        assert_available_for_adoption(&state.adoption, pet_id);
        let sender = tx_context::sender(ctx);
        assert_adopter(sender, roles);
        let owner_info_vector = create_pet_passport_vector(owner_info);
        vector::push_back(&mut owner_info_vector, address::to_string(sender));
        mint_passport_internal(
            pet.url, 
            pet.pet_info, 
            owner_info_vector, 
            pet.microchip_info, 
            sender, 
            payment, 
            state, 
            ctx
        );
        let (_found, index) = vector::index_of(&state.adoption, &pet_id);
        vector::remove(&mut state.adoption, index);
        pet.adopted = true;
        burn_adoption(pet, ctx);
    }

    //==============================================================================================
    // Helper Functions 
    //==============================================================================================

    fun assert_correct_payment(payment: u64){
        assert!(payment == PRICE, ERROR_INSUFFICIENT_FUNDS);
    }

    fun assert_available_for_adoption(for_adoption: &vector<ID>, pet_id: ID){
        assert!(vector::contains(for_adoption, &pet_id), ERROR_NOT_AVAILABLE_FOR_ADOPTION);
    }

    fun assert_adopted(adopted: bool){
        assert!(adopted, ERROR_NOT_ADOPTED_YET);
    }

    fun num_to_string(num: u64): String {
        use std::string;
        let num_vec = vector::empty<u8>();
        if (num == 0) {
            vector::push_back(&mut num_vec, 48);
        } else {
            while (num != 0) {
                let mod = num % 10 + 48;
                vector::push_back(&mut num_vec, (mod as u8));
                num = num / 10;
            };
        };
        vector::reverse(&mut num_vec);
        string::utf8(num_vec)
    }

    fun create_pet_passport_vector(
        info: String
    ): vector<String>{
        let info_vector = vector::empty<String>();
        let index = string::index_of(&info, &string::utf8(b";"));
        while(index != string::length(&info)){
            let word = string::sub_string(&info, 0, index);
            vector::push_back(&mut info_vector, string::sub_string(&info, 0, index));
            info = string::sub_string(&info, index+1, string::length(&info));
            index = string::index_of(&info, &string::utf8(b";"));
        };
        vector::push_back(&mut info_vector, info);
        info_vector
    }

    fun mint_passport_internal(
        url: String,
        pet_info: vector<String>,
        owner_info: vector<String>,
        microchip_info: vector<String>,
        receiver: address,
        payment: Coin<SUI>, 
        state: &mut State,
        ctx: &mut TxContext
    ) {
        assert_correct_payment(coin::value(&payment));
        transfer::public_transfer(payment, @treasury);
        
        let desc = *vector::borrow(&pet_info, 1);
        string::append_utf8(&mut desc, b", ");
        string::append(&mut desc, *vector::borrow(&pet_info, 2));
        string::append_utf8(&mut desc, b", ");
        string::append(&mut desc, *vector::borrow(&pet_info, 4));
        let name = string::utf8(b"Pet_#");
        string::append(&mut name, num_to_string(state.minted + 1));
        string::append_utf8(&mut name, b": ");
        string::append(&mut name, *vector::borrow(&pet_info, 0));

        let nft = PetPassport{
            id: object::new(ctx),
            name,
            description: desc,
            url: url::new_unsafe_from_bytes(*string::bytes(&url)),
            royalty_numerator: 5,
            pet_info,
            owner_info,
            microchip_info,
            vaccination_rec: vector::empty(),
            clinical_rec: vector::empty(),
        };
        state.minted = state.minted + 1;
        event::emit(PassportCreated {
            object_id: object::id(&nft),
            owner: receiver,
            name: nft.name,
        });
        transfer::transfer(nft, receiver);
    }

    /// Permanently delete `nft`
    public entry fun burn_adoption(
        nft: AdoptionPet, 
        _: &mut TxContext) 
    {
        assert_adopted(nft.adopted);
        let AdoptionPet { 
            id,
            url: _, 
            royalty_numerator: _,
            pet_info: _,
            microchip_info: _,
            adopted: _,
        } = nft;
        object::delete(id);
    }

    //==============================================================================================
    // Role Validation Functions
    //==============================================================================================

    fun assert_adopter(user: address, roles: &mut Roles) {
        assert!(role::is_adopter(user, roles) , ERROR_SIGNER_NOT_APPROVED_ADOPTER);
    }

    fun assert_vet(user: address, roles: &mut Roles) {
        assert!(role::is_vet(user, roles) , ERROR_SIGNER_NOT_VET);
    }

    fun assert_admin_or_operator(user: address, roles: &mut Roles) {
        assert!(user == @admin || role::is_operator(user, roles), ERROR_SIGNER_NOT_ADMIN_OR_OPERATOR);
    }

    //==============================================================================================
    // Tests 
    //==============================================================================================
    #[test]
    fun test_init_success() {
        let module_owner = @0xa;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            init(test_scenario::ctx(scenario));
        };
        let tx = test_scenario::next_tx(scenario, module_owner);
        let expected_events_emitted = 0;
        let expected_created_objects = 1;
        assert_eq(
            test_scenario::num_user_events(&tx), 
            expected_events_emitted
        );
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_mint_nft_success() {
        let module_owner = @0x0;
        let user = @0xa;
        
        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;
        test_scenario::next_tx(scenario, user);
        init(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, user);
        let pet_info = string::utf8(b"spot;dog;corgy;male;1/1/23;brown, white spots");
        let url = string::utf8(b"test_url");
        let owner_info = string::utf8(b"bob;bob@bobmail.com");
        let microchip_info = string::utf8(b"123;1/1/24;shoulder");
        {
            let state = test_scenario::take_shared<State>(scenario);
            let payment = coin::mint_for_testing<SUI>(PRICE, test_scenario::ctx(scenario));
            mint_passport(
                pet_info,
                url,
                owner_info,
                user,
                microchip_info,
                payment, 
                &mut state,
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(state);
        };
        
        let tx = test_scenario::next_tx(scenario, user);
        let expected_events_emitted = 1;
        assert_eq(
            test_scenario::num_user_events(&tx), 
            expected_events_emitted
        );

        {
            let nft = test_scenario::take_from_sender<PetPassport>(scenario);

            assert_eq(
                nft.name, 
                string::utf8(b"Pet_#1: spot")
            );

            test_scenario::return_to_sender(scenario, nft);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_add_vac_record_success() {
        let module_owner = @0x0;
        let user = @0xa; 
        let vet = @0xb;
        let admin = @0xb51c29c74c5e348dc58ad0a2e138299474b2463077ba150076907ff62885c900;
        
        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;
        test_scenario::next_tx(scenario, user);
        init(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, user);
        let pet_info = string::utf8(b"spot;dog;corgy;male;1/1/23;brown, white spots");
        let url = string::utf8(b"test_url");
        let owner_info = string::utf8(b"bob;bob@bobmail.com");
        let microchip_info = string::utf8(b"123;1/1/24;shoulder");
        {
            let state = test_scenario::take_shared<State>(scenario);
            let payment = coin::mint_for_testing<SUI>(PRICE, test_scenario::ctx(scenario));
            mint_passport(
                pet_info,
                url,
                owner_info,
                user,
                microchip_info,
                payment, 
                &mut state,
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(state);
        };
        role::init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, admin);
        {
            let roles = test_scenario::take_shared<Roles>(scenario);
            role::grant_role(vet, string::utf8(b"vet"), &mut roles, test_scenario::ctx(scenario));
            test_scenario::return_shared(roles);
        };
        test_scenario::next_tx(scenario, vet);
        {
            let nft = test_scenario::take_from_address<PetPassport>(scenario, user);
            let roles = test_scenario::take_shared<Roles>(scenario);
            add_vac(
                &mut nft,
                string::utf8(b"vac_date"),
                string::utf8(b"vac_ref_no"),
                string::utf8(b"date_valid_from"),
                string::utf8(b"expiry_date"),
                string::utf8(b"cert_image_uri"),
                &mut roles,
                test_scenario::ctx(scenario)  
            );
            test_scenario::return_to_address(user, nft);
            test_scenario::return_shared(roles);
        };
        test_scenario::next_tx(scenario, user);
        {
            let nft = test_scenario::take_from_sender<PetPassport>(scenario);
            assert_eq(
                vector::length(&nft.vaccination_rec), 
                1
            );
            test_scenario::return_to_sender(scenario, nft);
        };
        
        test_scenario::end(scenario_val);
    }

        #[test]
    fun test_add_clinical_record_success() {
        let module_owner = @0x0;
        let user = @0xa; 
        let vet = @0xb;
        let admin = @0xb51c29c74c5e348dc58ad0a2e138299474b2463077ba150076907ff62885c900;
        
        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;
        test_scenario::next_tx(scenario, user);
        init(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, user);
        let pet_info = string::utf8(b"spot;dog;corgy;male;1/1/23;brown, white spots");
        let url = string::utf8(b"test_url");
        let owner_info = string::utf8(b"bob;bob@bobmail.com");
        let microchip_info = string::utf8(b"123;1/1/24;shoulder");
        {
            let state = test_scenario::take_shared<State>(scenario);
            let payment = coin::mint_for_testing<SUI>(PRICE, test_scenario::ctx(scenario));
            mint_passport(
                pet_info,
                url,
                owner_info,
                user,
                microchip_info,
                payment, 
                &mut state,
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(state);
        };
        role::init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, admin);
        {
            let roles = test_scenario::take_shared<Roles>(scenario);
            role::grant_role(vet, string::utf8(b"vet"), &mut roles, test_scenario::ctx(scenario));
            test_scenario::return_shared(roles);
        };
        test_scenario::next_tx(scenario, vet);
        {
            let nft = test_scenario::take_from_address<PetPassport>(scenario, user);
            let roles = test_scenario::take_shared<Roles>(scenario);
            add_clinical_rec(
                &mut nft,
                string::utf8(b"date_time"),
                string::utf8(b"records"),
                &mut roles,
                test_scenario::ctx(scenario)  
            );
            test_scenario::return_to_address(user, nft);
            test_scenario::return_shared(roles);
        };
        test_scenario::next_tx(scenario, user);
        {
            let nft = test_scenario::take_from_sender<PetPassport>(scenario);
            assert_eq(
                vector::length(&nft.clinical_rec), 
                1
            );
            test_scenario::return_to_sender(scenario, nft);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_adopt_success() {
        let module_owner = @0x0;
        let user = @0xa;
        let admin = @0xb51c29c74c5e348dc58ad0a2e138299474b2463077ba150076907ff62885c900;
        
        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;
        test_scenario::next_tx(scenario, user);
        init(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, user);
        let pet_info = string::utf8(b"spot;dog;corgy;male;1/1/23;brown, white spots");
        let url = string::utf8(b"test_url");
        let owner_info = string::utf8(b"bob;bob@bobmail.com");
        let microchip_info = string::utf8(b"123;1/1/24;shoulder");
        let now;
        {
            let state = test_scenario::take_shared<State>(scenario);
            list_adoption(
                pet_info,
                url,
                microchip_info,
                &mut state,
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(state);
        };
        
        role::init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, admin);
        {
            let roles = test_scenario::take_shared<Roles>(scenario);
            role::grant_role(user, string::utf8(b"adopter"), &mut roles, test_scenario::ctx(scenario));
            test_scenario::return_shared(roles);
        };
        test_scenario::next_tx(scenario, user);
        {
            let roles = test_scenario::take_shared<Roles>(scenario);
            let state = test_scenario::take_shared<State>(scenario);
            let pet = test_scenario::take_shared<AdoptionPet>(scenario);
            let payment = coin::mint_for_testing<SUI>(PRICE, test_scenario::ctx(scenario));
            adopt(pet, owner_info, payment, &mut roles, &mut state, test_scenario::ctx(scenario));
            test_scenario::return_shared(roles);
            test_scenario::return_shared(state);
        };
        test_scenario::end(scenario_val);
    }

}
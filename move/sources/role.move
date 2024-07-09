#[allow(unused_mut_parameter, unused_use)]
module deployer::role {
    
    use std::vector;
    use std::string::{Self, String};
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::transfer;
    use sui::object::{Self, ID, UID};

    //==============================================================================================
    // Error codes
    //==============================================================================================

    const ERROR_SIGNER_NOT_ADMIN: u64 = 0;
    const ERROR_SIGNER_NOT_OPERATOR: u64 = 1;
    const ERROR_INVALID_ROLE_NAME: u64 = 2;
    const ERROR_USER_NO_ROLE: u64 = 3;
    const ERROR_USER_ALREADY_HAS_ROLE: u64 = 4;


    //==============================================================================================
    // Structs 
    //==============================================================================================
    struct Roles has key{
        id: UID,
        operator: vector<address>,
        adopter: vector<address>, //approved eligible adopter
        vet: vector<address>,
    }

    struct RoleNFT has key{
        id: UID,
        role: String,
        owner: address
    }
    //==============================================================================================
    // Event structs
    //==============================================================================================

    struct RoleGrantedEvent has copy, drop {
        // approver
        approver: address,
        // role
        role: String,
        // user address
        user: address
    }

    struct RoleRevokedEvent has copy, drop {
        // executor
        executor: address,
        // role
        role: String,
        // user address
        user: address
    }

    //==============================================================================================
    // Init
    //==============================================================================================

    fun init(ctx: &mut TxContext) {
        transfer::share_object(Roles{
            id: object::new(ctx), 
            operator: vector::empty(),
            adopter: vector::empty(),
            vet: vector::empty(),
        });
    }

    //==============================================================================================
    // Entry Functions
    //==============================================================================================

    /*
    Grants reviewer/operator roles
    @param admin - admin signer
    @param user - user address
    @param role - reviewer/operator
*/
    public entry fun grant_role(
        user: address,
        role: String,
        roles: &mut Roles,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert_appropriate_role(role);
        assert_user_does_not_have_role(user, roles);
        if(role == string::utf8(b"operator")){
            assert_admin(sender);
            vector::push_back(&mut roles.operator, user);
        }else{
            assert_admin_or_operator(sender, roles);
            if(role == string::utf8(b"adopter")){
                vector::push_back(&mut roles.adopter, user);
            }else{
                vector::push_back(&mut roles.vet, user);
            };
        };
        let nft = RoleNFT{
            id: object::new(ctx),
            role,
            owner: sender
        };
        transfer::transfer(nft, sender);
        // Emit a new RoleGrantedEvent
        event::emit(RoleGrantedEvent {
            approver: sender,
            role,
            user,
        });
    }

    /*
    Revoke reviewer/operator roles
    @param admin - admin signer
    @param user - user address
    @param role - reviewer/operator
*/
    public entry fun revoke_role(
        user: address,
        roles: &mut Roles,
        roleNFT: RoleNFT,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert_user_has_role(user, roles);
        let role;
        if(vector::contains(&roles.operator, &user)){
            assert_admin(sender);
            let (_found, index) = vector::index_of(& roles.operator, &user);
            vector::remove(&mut roles.operator, index);
            role = string::utf8(b"operator");
        }else{
            assert_admin_or_operator(sender, roles);
            if(vector::contains(&roles.adopter, &user)){
                let (_found, index) = vector::index_of(& roles.adopter, &user);
                vector::remove(&mut roles.adopter, index);
                role = string::utf8(b"adopter");
            }else{
                let (_found, index) = vector::index_of(& roles.vet, &user);
                vector::remove(&mut roles.vet, index);
                role = string::utf8(b"vet");
            }
        };
        burn(roleNFT, roles, ctx);
        // Emit a new RoleRevokedEvent
        event::emit(RoleRevokedEvent {
            executor: sender,
            role,
            user,
        });
    }

    //==============================================================================================
    // Helper Functions
    //==============================================================================================
    /// Permanently delete `nft`
    public entry fun burn(
        nft: RoleNFT, 
        roles: &mut Roles,
        ctx: &mut TxContext) 
    {
        let sender = tx_context::sender(ctx);
        assert_admin_or_operator(sender, roles);
        let RoleNFT { 
            id,
            role: _, 
            owner: _,
        } = nft;
        object::delete(id);
    }

    //==============================================================================================
    // Validation Functions
    //==============================================================================================

    fun assert_appropriate_role(role: String) {
        assert!(role == string::utf8(b"operator") || role == string::utf8(b"adopter") || role == string::utf8(b"vet"), ERROR_INVALID_ROLE_NAME);
    }

    fun assert_user_has_role(user: address, roles: &mut Roles) {
        assert!(
            vector::contains(&roles.adopter, &user) || vector::contains(&roles.operator, &user) || vector::contains(&roles.vet, &user), 
            ERROR_USER_NO_ROLE
        );
    }

    fun assert_user_does_not_have_role(user: address, roles: &mut Roles) {
        assert!(
            !vector::contains(&roles.adopter, &user) && !vector::contains(&roles.operator, &user) && !vector::contains(&roles.vet, &user), 
            ERROR_USER_ALREADY_HAS_ROLE
            );
    }

    fun assert_admin(user: address) {
        assert!(user == @admin, ERROR_SIGNER_NOT_ADMIN);
    }
    
    fun assert_admin_or_operator(user: address, roles: &mut Roles) {
        assert!(user == @admin || vector::contains(&roles.operator, &user), ERROR_SIGNER_NOT_OPERATOR);
    }

    //==============================================================================================
    // Check Functions
    //==============================================================================================

    public fun is_adopter(user: address, roles: &Roles): bool {
        vector::contains(&roles.adopter, &user)
    }

    public fun is_vet(user: address, roles: &Roles): bool {
        vector::contains(&roles.vet, &user)
    }

    public fun is_operator(user: address, roles: &Roles): bool {
        vector::contains(&roles.operator, &user)
    }

    //==============================================================================================
    // TESTS
    //==============================================================================================

     #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }

}
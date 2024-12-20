

module deployer::gui_charity2{
    use std::bcs;
    use std::event;
    use std::signer;
    use std::vector;
    use std::type_info;
    use std::string_utils;
    use std::string::{Self, String};
    
    
    use aptos_framework::coin;
    use aptos_framework::aptos_account;
    use aptos_framework::object::{Self};
    use aptos_framework::account::{Self, SignerCapability};



    use aptos_token_objects::token;

    use aptos_token_objects::collection::{Collection};
    use aptos_token_objects::aptos_token::{Self,AptosToken};


    
    // Constants
    const SEED: vector<u8> = b"GUI Charity";

    const COLLECTION_NAME: vector<u8> = b"GUI Charity";

    // ERRORS
    // Caller not admint
    const ENOT_ADMIN: u64 = 1;

    // Caller isn't the token owner
    const ENOT_OWNER: u64 = 2;

    // The token isn't from the Collection
    const ENOT_TOKEN_FROM_COLLECTION: u64 = 3;

    // The caller is not apointed as the next admin
    const ENOT_APOINTED_ADMIN: u64 = 4;


    struct ControlData has key {
        // Has control over the code
        admin: address,
        // Resource account 
        resource_cap: SignerCapability,

        donation_address: address,
    }

    struct TempAdmin has key {
        temp: address,
    }

    struct ValidCoin has key{
        name: String,
        symbol: String,
        coin_address: address,
    }

    struct CollectionData has key {
        supply: u64,
    }

    struct TokenData has key {
        name: vector<u8>,
        description: vector<u8>,
        uri: vector<u8>
    }


    //  EVENTS
    #[event]
    struct DonationEvent has drop,store {
        donor: address,
        amount: u64,
        charity: String,
        message: String,
    }
    

  
    fun init_module(creator: &signer){
        // Create the resource account which will hold the collection
        let (_resource, resource_cap) = account::create_resource_account(creator, SEED);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_cap);


        move_to(creator, ControlData{
            admin: signer::address_of(creator),
            resource_cap: resource_cap,
            donation_address: @0x0,
        });

        move_to(creator, CollectionData{
            supply: 0,
        });

        move_to(creator, TokenData{
            name: b"Gui Charity Donor Token",
            description: b"Gui Charity donor description",
            uri: b"https://arweave.net/JgXp079FBp6SWv5v0A3tBIGrEPiGt8quCSwgxSJRbcA",
        });
        
        move_to(creator, ValidCoin{
            name: string::utf8(b""),
            symbol: string::utf8(b""),
            coin_address: @0x0,
        });

        i_create_collection(&resource_signer_from_cap);
    }


    public entry fun donate<CoinType>(caller: &signer,amount: u64, charity: String, message: String) acquires ValidCoin,ControlData,TokenData, CollectionData {
        // Check that the coin is GUI-INU
        check_coin<CoinType>();

        // Transfer the coin from caller to donation address
        get_payment<CoinType>(caller, amount);

        // Mint a nft to the donor
        i_mint(signer::address_of(caller),amount,charity,message);

        // Emit the donation event
        event::emit(DonationEvent{
            donor: signer::address_of(caller),
            amount: amount,
            charity: charity,
            message: message,
        })

    }


    ////////////////////////
    ///////// SETS ///////// 
    ////////////////////////

    public entry fun set_admin(caller: &signer, new_admin: address) acquires ControlData, TempAdmin{
        admin_only(caller);

        let temp = &mut TempAdmin[@deployer];
        temp.temp = new_admin;
    }

    public entry fun accept_admin(caller: &signer) acquires ControlData, TempAdmin{
        let temp = &mut TempAdmin[@deployer];

        assert!(temp.temp == signer::address_of(caller), ENOT_APOINTED_ADMIN);

        temp.temp = @0x1;

        let control = &mut ControlData[@deployer];
        control.admin = signer::address_of(caller);
  
    }

    public entry fun set_donation_address(caller: &signer, new_address: address) acquires ControlData{
        admin_only(caller);

        let control = &mut ControlData[@deployer];
        control.donation_address = new_address;
    }

    public entry fun set_valid_coin<CoinType>(caller: &signer) acquires ValidCoin,ControlData{
        admin_only(caller); 

        let type_info = type_info::type_of<CoinType>();
        let coin_address = type_info::account_address(&type_info);
        let name = coin::name<CoinType>();
        let symbol = coin::symbol<CoinType>();

        let coin = &mut ValidCoin[@deployer];

        coin.name = name;
        coin.symbol = symbol;
        coin.coin_address = coin_address;
    }

    public entry fun set_token_name(caller: &signer, new_name: String) acquires ControlData,TokenData{
        admin_only(caller);

        let token = &mut TokenData[@deployer];
        token.name = *new_name.bytes();
    }

    public entry fun set_token_description(caller: &signer, new_description: String) acquires ControlData,TokenData{
        admin_only(caller);

        let token = &mut TokenData[@deployer];
        token.description = *new_description.bytes();
    }

    public entry fun set_token_uri(caller: &signer, new_uri: String) acquires ControlData,TokenData{
        admin_only(caller);

        let token = &mut TokenData[@deployer];
        token.uri = *new_uri.bytes();
    }

    public entry fun update_collection_description(caller: &signer, token_from_collection: address, new_description: String) acquires ControlData{
        admin_only(caller);

        let token_object = object::address_to_object<AptosToken>(token_from_collection);
        let collection_object = token::collection_object<AptosToken>(token_object);
        
        
        let creator = get_creator();

        aptos_token::set_collection_description<Collection>(&creator,collection_object, new_description);

    }

    public entry fun update_collection_uri(caller: &signer, token_from_collection: address, new_uri: String) acquires ControlData{
        admin_only(caller);

        let token_object = object::address_to_object<AptosToken>(token_from_collection);
        let collection_object = token::collection_object<AptosToken>(token_object);
        
        
        let creator = get_creator();

        aptos_token::set_collection_uri<Collection>(&creator,collection_object, new_uri);

    }

    public entry fun update_token_name(caller: &signer, object_address: address, new_name: String) acquires ControlData{
        admin_only(caller);

        let token_object = object::address_to_object<AptosToken>(object_address);
        let creator = get_creator();

        aptos_token::set_name(&creator, token_object,new_name);

    }

    public entry fun update_token_description(caller: &signer, object_address: address, new_description: String) acquires ControlData{
        admin_only(caller);

        let token_object = object::address_to_object<AptosToken>(object_address);
        let creator = get_creator();

        aptos_token::set_description(&creator, token_object,new_description);

    }

    public entry fun update_token_uri(caller: &signer, object_address: address, new_uri: String) acquires ControlData{
        admin_only(caller);

        let token_object = object::address_to_object<AptosToken>(object_address);
        let creator = get_creator();

        aptos_token::set_uri(&creator, token_object,new_uri);

    }

    
    ////////////////////////////
    ///////// INTERNAL ///////// 
    ////////////////////////////
    
    fun i_create_collection(creator: &signer){

        let collection_description = string::utf8(b"Gui Charity Description");
        let collection_uri = string::utf8(b"https://arweave.net/QCleF8cknIWsO1KceGYrqgugIAzOWGjqMivUC3oYzLM");
        let supply = 9223372036854775807;
        let royalty_numerator = 10;
        let royalty_denominator = 10;


        // Create the collection to be minted
        aptos_token::create_collection_object(
            creator,
            collection_description,
            supply,
            string::utf8(COLLECTION_NAME),
            collection_uri,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            royalty_numerator,
            royalty_denominator
        );


    }

    fun i_mint(to_address: address, amount: u64, charity: String, message: String) acquires TokenData, CollectionData, ControlData{

        let token_data = &TokenData[@deployer];

        
        // Get the collection creator
        let creator = get_creator();


        // Min the soulbound token
        aptos_token::mint_soul_bound_token_object(
            &creator,
            string::utf8(COLLECTION_NAME),
            string::utf8(token_data.description),
            string::utf8(token_data.name),
            string::utf8(token_data.uri),
            vector[string::utf8(b"amount"), string::utf8(b"charity"), string::utf8(b"message")],
            vector[string::utf8(b"u64"), string::utf8(b"vector<u8>"), string::utf8(b"vector<u8>")],
            vector[bcs::to_bytes<u64>(&amount),*charity.bytes(), *message.bytes()],
            to_address
        );

        // Update deng created amount
        let collection_data = &mut CollectionData[@deployer];
        collection_data.supply += 1;

    } 
 
    fun get_payment<CoinType>(caller:&signer, amount:u64) acquires ControlData{
        // Get struct to obtian price
        let control = &ControlData[@deployer];


        // Store half in resource account
        // coin::transfer<CoinType>(caller,control.donation_address, amount);
        aptos_account::transfer_coins<CoinType>(caller,control.donation_address, amount);
    }

    fun check_coin<CoinType>() acquires ValidCoin{
    
        let valid_coin = &ValidCoin[@deployer];

        let type_info = type_info::type_of<CoinType>();
        let passed_coin_adress = type_info::account_address(&type_info);
        
        assert!(passed_coin_adress == valid_coin.coin_address, 0);
        assert!(coin::name<CoinType>() == valid_coin.name);
        assert!(coin::symbol<CoinType>() == valid_coin.symbol);
    }


    fun admin_only(caller: &signer) acquires ControlData{
      let data = &ControlData[@deployer];    
      assert!(data.admin == signer::address_of(caller), ENOT_ADMIN);
    }

    fun get_creator(): signer acquires ControlData{
      let control_data = &ControlData[@deployer];
      account::create_signer_with_capability(&control_data.resource_cap)
    }

    #[test_only]
    use deployer::tu::{Self,Coin1};

    #[test(aptos_framework = @0x1, deployer = @deployer, user1 = @user1, user2 = @user2)]
    fun test__donate_once(aptos_framework: &signer, deployer: &signer, user1: &signer, user2: &signer) acquires CollectionData, TokenData, ControlData, ValidCoin{
        init_module(deployer);
        tu::init(aptos_framework, deployer);


        tu::get_apt(user1,100);
        tu::get_apt(user2,100);


        // Obtain user addr
        let user_address_1 = signer::address_of(user1);
        let user_address_2 = signer::address_of(user2);
        let deployer_address = signer::address_of(deployer);

        // Get coinf for both users
        tu::get_coins<Coin1>(user1, 100);
        tu::get_coins<Coin1>(user2, 100);

        // Set valid coin for donations
        set_valid_coin<Coin1>(deployer);

        // Set donation address to deployer
        set_donation_address(deployer, deployer_address);


        assert!(coin::balance<Coin1>(user_address_1) == 100);


        donate<Coin1>(user1, 10, string::utf8(b"Mine"), string::utf8(b"I want to :D"));

        assert!(coin::balance<Coin1>(user_address_1) == 90);
        assert!(coin::balance<Coin1>(deployer_address) == 10);

    }

}
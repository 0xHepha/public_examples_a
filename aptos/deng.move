module creator::deng_v2 {
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use std::string_utils;
    use std::type_info;
    use std::event;
    
    
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::object::{Self};
    use aptos_framework::coin;


    use aptos_token_objects::token;

    use aptos_token_objects::aptos_token::{Self,AptosToken};
    use aptos_token_objects::collection::{Collection};


    // Constants
    const SEED: vector<u8> = b"DENG #69 + v2";


    // ERRORS
    // Caller not admint
    const ENOT_ADMIN: u64 = 1;

    // Caller isn't the token owner
    const ENOT_OWNER: u64 = 2;

    // The token isn't from Deng Collection
    const ENOT_TOKEN_FROM_COLLECTION: u64 = 3;

    // Used to burn Modeng supply
    const BURN_WALLET: address = @BURN_WALLET;

    

    struct ControlData has key {
        // Has control over the code
        admin: address,

        // Address to send tokens to
        out_address: address,

        // Resource account 
        resource_cap: SignerCapability,

        // Address of the deng soulbound collection 
        collection_address:address,

        // Address of the coin accepted as payment: <Modegn> by defualt 
        coin_address: address,

        // Price to create/delete dengs
        price:u64,

        // Amount of created Dengs
        deng_created_amount: u64,

        // Amount of token burns
        burnt_amount: u64

    }


    // =========== EVENTS ===========
    #[event]
    struct DengSent has drop, store {
      by_address: address,
      to_address: address,
      link: String
    }

    #[event]
    struct DengRemoved has drop,store{  
      // we use a string here due to the compilation of an efective casting from string to address
      // Since the sent_by address is obtainerd from the token descrition
      sent_by_address: String,
      removed_by_address: address,
      link: String
    } 

    fun init_module(creator: &signer){
        createCollection_internal(creator);
    }


    public entry fun mark<CoinType>(caller: &signer, to_address: address, token_uri: String) acquires ControlData{     
      // Only Modeng is acepted as payment
      coin_is_modeng<CoinType>();

      // Process payment
      get_payment<CoinType>(caller, 1);

      // Mint a souldbound to caller
      mint_internal(caller, to_address, token_uri);

      // Emit the event
      event::emit( DengSent{
        by_address: signer::address_of(caller),
        to_address: to_address,
        link: token_uri 
      });
    }
    
    
    public entry fun mark_release<CoinType>(caller: &signer, token_uri: String, addresses:vector<address>) acquires ControlData{
      // Only admin can send multiple dengs
      admin_only(caller);

      // Only Modeng is acepted as payment
      coin_is_modeng<CoinType>();
      
      // Get amount of addresses to send a deng to
      let address_amount = vector::length(&addresses); 

      // Process payment for sending to all the addresses
      get_payment<CoinType>(caller, address_amount);
      
      let i = 0;
      while(i < address_amount){
        // get an address
        let to_address = vector::borrow(&addresses,i);
        
        // mint a soulbound to it
        mint_internal(caller,*to_address, token_uri);

        // Emit the event
        event::emit(DengSent{
          by_address: signer::address_of(caller),
          to_address: *to_address,
          link: token_uri 
        });

        i = i + 1;
      }


    }


    public entry fun remove<CoinType>(caller: &signer, token_address:address )acquires ControlData{
        // Check the caller is the owner of the soulbound
        // This is to avoid others removing the soulbounds, they would pay either way, but this makes it more anoying :)
        owner_only(caller,token_address);

        // Check coin to take is modeng
        coin_is_modeng<CoinType>();

          // Process payment
        get_payment<CoinType>(caller, 1);
        
        // Get the token object
        let token_object = object::address_to_object<AptosToken>(token_address);

        // Get Description of the token
        let token_description = token::description(token_object);

        // Obtian sender address from description string
        let sent_by_address = string::sub_string(&token_description,71,137);

        // Get token uri
        let token_uri = token::uri(token_object);

        // Get resource singer/creator
        let creator = get_creator();

        // Delete soulbound token
        aptos_token::burn<AptosToken>(&creator, token_object);

        // Emit the event
        event::emit(DengRemoved{
          sent_by_address: sent_by_address,
          removed_by_address: signer::address_of(caller),
          link: token_uri 
        });

    }

    // In all change functions admin_only() function is used only if ControlData struct info isn't needed along the function
    // If further access is needed, the used of admin_only() call is avoided to reduce gas cost, even is minuscule
   
    public entry fun change_collection_address(caller: &signer, new_address: address) acquires ControlData{
      let control_data = borrow_global_mut<ControlData>(@creator);    
      assert!(control_data.admin == signer::address_of(caller), ENOT_ADMIN);
      
      control_data.collection_address = new_address;
    }


    public entry fun change_coin_address(caller: &signer, new_address: address)acquires ControlData{
      let control_data = borrow_global_mut<ControlData>(@creator);    
      assert!(control_data.admin == signer::address_of(caller), ENOT_ADMIN);

      control_data.coin_address = new_address;

    }

    public entry fun change_collection_uri(caller: &signer,token_address: address, new_uri:String) acquires ControlData{
      admin_only(caller);

      let token_object = object::address_to_object<AptosToken>(token_address);
      let collection_object_from_token = token::collection_object<AptosToken>(token_object);
      let creator = get_creator();

      aptos_token::set_collection_uri<Collection>(&creator,collection_object_from_token, new_uri);
    }


    public entry fun change_collection_description(caller: &signer,token_address: address, new_description:String) acquires ControlData{
      admin_only(caller);

      let token_object = object::address_to_object<AptosToken>(token_address);
      let collection_object_from_token = token::collection_object<AptosToken>(token_object);
      let creator = get_creator();

      aptos_token::set_collection_description<Collection>(&creator,collection_object_from_token, new_description);

    }

    public entry fun change_price(caller: &signer, new_price: u64) acquires ControlData{
      let control_data = borrow_global_mut<ControlData>(@creator);    
      assert!(control_data.admin == signer::address_of(caller), ENOT_ADMIN);

      control_data.price = new_price;
    }

    public entry fun change_admin(caller: &signer, new_admin_address: address) acquires ControlData{
      let control_data = borrow_global_mut<ControlData>(@creator);    
      assert!(control_data.admin == signer::address_of(caller), ENOT_ADMIN);

      control_data.admin = new_admin_address;
    }

    public entry fun change_out_address(caller: &signer, new_out_address: address) acquires ControlData{
      let control_data = borrow_global_mut<ControlData>(@creator);    
      assert!(control_data.admin == signer::address_of(caller), ENOT_ADMIN);

      control_data.out_address = new_out_address;
    }


    ////////////////////////
    ///////// VIEW ///////// 
    ////////////////////////
    #[view]
    public fun get_burnt_amount():u64 acquires ControlData{
      let control_data = borrow_global_mut<ControlData>(@creator);   
      control_data.burnt_amount 
    }

    #[view]
    public fun deng_created_amount():u64 acquires ControlData{
      let control_data = borrow_global_mut<ControlData>(@creator);   
      control_data.deng_created_amount
    }



    ////////////////////////////
    ///////// INTERNAL ///////// 
    ////////////////////////////
    
    fun createCollection_internal(creator: &signer){
      let collection_name = string::utf8(b"Deng");
      let collection_description = string::utf8(b"Just go to https://x.com/0xmodeng and get some $MODENG");

      let collection_uri = string::utf8(b"https://arweave.net/QCleF8cknIWsO1KceGYrqgugIAzOWGjqMivUC3oYzLM");
      let supply = 9223372036854775807;
      let royalty_numerator = 100;
      let royalty_denominator = 1000;

      // Create the resource account which will hold the collection
      let (_resource, resource_cap) = account::create_resource_account(creator, SEED);
      let resource_signer_from_cap = account::create_signer_with_capability(&resource_cap);
      
      // Store the resource cap in the object

      move_to(creator, ControlData{
          admin: signer::address_of(creator),
          out_address: signer::address_of(creator),
          resource_cap: resource_cap,
          collection_address: @creator,
          coin_address: @0xf49cfdec294462b0a1f30a4e1169c3390ef88f8807a36ebb047383f71be427e9,
          price: 100000000,
          deng_created_amount: 0,
          burnt_amount: 0
      });

      // Create the collection to be minted
      aptos_token::create_collection_object(
          &resource_signer_from_cap,
          collection_description,
          supply,
          collection_name,
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

    fun mint_internal(caller: &signer, to_address: address, token_uri: String) acquires ControlData{

      let collection_name = string::utf8(b"Deng");
      let token_description = string::utf8(b"This is a Deng! Go to https://x.com/0xmodeng for extra info. Sent by <");

      string::append(&mut token_description, string_utils::to_string<address>(&signer::address_of(caller)));
      string::append(&mut token_description, string::utf8(b">"));


      // Get the collection creator
      let creator = get_creator();

      // Prepare the token name by adding the id to the collection name
      let token_name = string::utf8(b"Deng #69");

      // Min the soulbound token
      aptos_token::mint_soul_bound_token_object(
          &creator,
          collection_name,
          token_description,
          token_name,
          token_uri,
          vector::empty<String>(),
          vector::empty<String>(),
          vector::empty<vector<u8>>(),
          to_address
      );

      // Update deng created amount
      let control_data = borrow_global_mut<ControlData>(@creator);
      control_data.deng_created_amount = control_data.deng_created_amount + 1;

    }
 
    ////////////////////////////
    ///////// HELPERS ///////// 
    ////////////////////////////
    fun owner_only(caller:&signer, token_address: address)acquires ControlData{
        let caller_address = signer::address_of(caller);

        // Get the token object
        let token_object = object::address_to_object<AptosToken>(token_address);

        // Check caller posses the token
        assert!(object::is_owner<AptosToken>(token_object,caller_address),0);

        // Get data for accepted collection address
        let control_data = borrow_global<ControlData>(@creator);

        // Get the collection object 
        let collection_object = object::address_to_object<Collection>(control_data.collection_address);

        // Get the collection that the submited token is part of
        let collection_object_from_token = token::collection_object<AptosToken>(token_object);

        // Check that is the valid collection
        assert!(collection_object_from_token == collection_object, ENOT_TOKEN_FROM_COLLECTION);
    }

    fun get_payment<CoinType>(caller:&signer, deng_amount:u64) acquires ControlData{
      // Get struct to obtian price
      let control_data = borrow_global_mut<ControlData>(@creator);

      // To avoid large lines... :/
      let half_amount = (control_data.price * deng_amount) / 2;

      // Burn half of it
      coin::transfer<CoinType>(caller,BURN_WALLET,half_amount);

      // Store half in resource account
      coin::transfer<CoinType>(caller,control_data.out_address, half_amount);

      //Update burnt amount
      control_data.burnt_amount = control_data.burnt_amount + half_amount;

    }

    fun coin_is_modeng<CoinType>() acquires ControlData{
      let control_data = borrow_global<ControlData>(@creator);
      let type_info = type_info::type_of<CoinType>();
      let passed_coin_adress = type_info::account_address(&type_info);
      
      assert!(passed_coin_adress == control_data.coin_address, 0);
      assert!(coin::name<CoinType>() == string::utf8(b"Mo Deng"),0);
      assert!(coin::symbol<CoinType>() == string::utf8(b"MODENG"),0);
    }

    fun admin_only(caller: &signer) acquires ControlData{
      let data = borrow_global_mut<ControlData>(@creator);    
      assert!(data.admin == signer::address_of(caller), ENOT_ADMIN);
    }

    fun get_creator(): signer acquires ControlData{
      let control_data = borrow_global<ControlData>(@creator);
      account::create_signer_with_capability(&control_data.resource_cap)
    }

}
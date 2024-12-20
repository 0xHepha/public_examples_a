module creator::geckoGenesis {
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use std::string_utils;
    use std::option;
    
    

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::object::{Self};


    use aptos_token_objects::token;
    use aptos_token_objects::royalty;

    use aptos_token_objects::aptos_token::{Self,AptosToken};

    // Constants
    const SEED: vector<u8> = b"33";

    // ERRORS
    // Caller not admint
    const ENOT_ADMIN: u64 = 1;


    struct ControlData has key {
        /// Signer capability for the resource account
        admin: address,
        resource_cap: SignerCapability
    }

    struct GenesisData has key {
        // Stores info about the collection
        tokens_amount: u64

    }


    fun init_module(creator: &signer){
        createCollection_internal(creator);


        move_to(creator, GenesisData{
          tokens_amount: 0
        });
    }


    
    fun createCollection_internal(creator: &signer){
      let collection_name = string::utf8(b"Gecko Genesis");
      let collection_description = string::utf8(b"Survivors, bearing the marks of ancient power and mystery. Each gecko carries the legacy of resilience, adaptation, and the untold secrets of an era washed away by the deluge.");
      let collection_uri = string::utf8(b"https://arweave.net/QCleF8cknIWsO1KceGYrqgugIAzOWGjqMivUC3oYzLM");
      let supply = 283;
      let royalty_numerator = 100;
      let royalty_denominator = 1000;

      // Create the resource account which will hold the collection
      let (_resource, resource_cap) = account::create_resource_account(creator, SEED);
      let resource_signer_from_cap = account::create_signer_with_capability(&resource_cap);
      
      // Store the resource cap in the object

      move_to(creator, ControlData{
          admin: signer::address_of(creator),
          resource_cap: resource_cap
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

    fun mint_internal(to_address: address) acquires GenesisData, ControlData{     
      let collection_name = string::utf8(b"Gecko Genesis");
      let collection_description = string::utf8(b"Survivors, bearing the marks of ancient power and mystery. Each gecko carries the legacy of resilience, adaptation, and the untold secrets of an era washed away by the deluge.");
      let token_uri = string::utf8(b"https://arweave.net/QCleF8cknIWsO1KceGYrqgugIAzOWGjqMivUC3oYzLM");

      let data = borrow_global_mut<GenesisData>(@creator);

      // Get the collection creator
      let creator = get_creator();

      // Prepare the token name by adding the id to the collection name
      let token_name = collection_name;
      string::append(&mut token_name, string::utf8(b" #"));
      string::append(&mut token_name, string_utils::to_string<u64>(&data.tokens_amount));

      // Min the token
      let minted_token = aptos_token::mint_token_object(
          &creator,
          collection_name,
          collection_description,
          token_name,
          token_uri,
          vector::empty<String>(),
          vector::empty<String>(),
          vector::empty<vector<u8>>()
      );


      object::transfer(&creator, minted_token, to_address);

      data.tokens_amount = data.tokens_amount + 1;

    }

    public entry fun mint_to(caller: &signer, amount:u64, to: address) acquires GenesisData, ControlData{
      admin_only(caller);

      let i = 0;
      while (i < amount){
        mint_internal(to);
        i = i + 1;
      }

    }


    public entry fun change_uri(caller: &signer, object_address: address, new_uri: String) acquires ControlData{
      admin_only(caller);

      let token_object = object::address_to_object<AptosToken>(object_address);
      let creator = get_creator();

      aptos_token::set_uri(&creator, token_object,new_uri);
      
    }


    public entry fun change_royalty(caller: &signer, token_address: address,  new_numerator: u64, new_denominator: u64, to: address) acquires ControlData{
      admin_only(caller);

      let creator = get_creator();

      let token_object = object::address_to_object<AptosToken>(token_address);
      let collection_object_from_token = token::collection_object<AptosToken>(token_object);

      let new_royalty = royalty::create(new_numerator, new_denominator, to);

      aptos_token::set_collection_royalties(&creator, collection_object_from_token, new_royalty);
    }
 

    fun get_creator(): signer acquires ControlData{
      let resource_data = borrow_global<ControlData>(@creator);
      account::create_signer_with_capability(&resource_data.resource_cap)
    }

    fun admin_only(caller: &signer) acquires ControlData{
      let data = borrow_global_mut<ControlData>(@creator);    
      assert!(data.admin == signer::address_of(caller), ENOT_ADMIN);
    }

    public entry fun change_admin(caller: &signer, new_admin: address) acquires ControlData{
      let data = borrow_global_mut<ControlData>(@creator);    
      assert!(data.admin == signer::address_of(caller), ENOT_ADMIN);
      
      data.admin = new_admin;
    }

}
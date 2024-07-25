module supply_chain_program :: supply_chain
module supply_chain::Management {
    use std::signer;
    use std::vector;
    use std::simple_map::{Self, SimpleMap};
    use std::account;

    // Define statuses
    const STATUS_PENDING: u8 = 1;
    const STATUS_SHIPPING: u8 = 2;
    const STATUS_DELIVERED: u8 = 3;

    // Define errors
    const E_SHIPMENT_ALREADY_EXISTS: u64 = 1;
    const E_SHIPMENT_NOT_FOUND: u64 = 2;
    const E_INVALID_STATUS_UPDATE: u64 = 3;

    // Define a Shipment structure
    struct Shipment has key {
        id: u64,
        status: u8,
        origin: address,
        destination: address,
    }

    // Store the shipments
    struct ShipmentList has key {
        shipments: SimpleMap<u64, Shipment>,
    }

    // Helper function to get the status name
    public fun get_status_name(status: u8): vector<u8> {
        if (status == STATUS_PENDING) {
            b"Pending"
        } else if (status == STATUS_SHIPPING) {
            b"Shipping"
        } else if (status == STATUS_DELIVERED) {
            b"Delivered"
        } else {
            b"Cancelled"
        }
    }

    // Initialize the ShipmentList 
    public entry fun initialize_supply_chain(acc: &signer) acquires ShipmentList {
        let addr = signer::address_of(acc);
        let shipment_list = ShipmentList {
            shipments: simple_map::create(),
        };
        move_to(acc, shipment_list);
    }

    // Create a new shipment
    public entry fun create_shipment(acc: &signer, id: u64, origin: address, destination: address) acquires ShipmentList {
        let addr = signer::address_of(acc);
        let shipment_list = borrow_global_mut<ShipmentList>(addr);

        assert!(!simple_map::contains_key(&shipment_list.shipments, &id), E_SHIPMENT_ALREADY_EXISTS);

        let shipment = Shipment {
            id,
            status: STATUS_PENDING,
            origin,
            destination,
        };

        simple_map::add(&mut shipment_list.shipments, id, shipment);
    }

    // Update shipment status
    public entry fun update_shipment_status(acc: &signer, id: u64, new_status: u8) acquires ShipmentList {
        let addr = signer::address_of(acc);
        let shipment_list = borrow_global_mut<ShipmentList>(addr);

        assert!(simple_map::contains_key(&shipment_list.shipments, &id), E_SHIPMENT_NOT_FOUND);

        let shipment = simple_map::borrow_mut(&mut shipment_list.shipments, &id);

        // Validate status transition
        assert!(
            (shipment.status == STATUS_PENDING && new_status == STATUS_SHIPPING) ||
            (shipment.status == STATUS_SHIPPING && new_status == STATUS_DELIVERED),
            E_INVALID_STATUS_UPDATE
        );

        shipment.status = new_status;
    }

    // Test functions
    #[test(admin = @supply_chain_program)]
    public entry fun test_create_and_update_shipment(admin: signer) acquires ShipmentList {
        let shipment_id = 1;
        let origin = @0x1;
        let destination = @0x2;
        initialize_supply_chain(&admin);
        create_shipment(&admin, shipment_id, origin, destination);

        let shipment_list = &borrow_global<ShipmentList>(signer::address_of(&admin)).shipments;
        assert!(simple_map::contains_key(shipment_list, &shipment_id), 0);

        update_shipment_status(&admin, shipment_id, STATUS_SHIPPING);
        let shipment = simple_map::borrow(shipment_list, &shipment_id);
        assert!(shipment.status == STATUS_SHIPPING, 0);

        update_shipment_status(&admin, shipment_id, STATUS_DELIVERED);
        let shipment = simple_map::borrow(shipment_list, &shipment_id);
        assert!(shipment.status == STATUS_DELIVERED, 0);
    }

    #[test(admin =@supply_chain_program)]
    #[expected_failure(abort_code = E_SHIPMENT_ALREADY_EXISTS)]
    public entry fun test_create_existing_shipment(admin: signer) acquires ShipmentList {
        let shipment_id = 1;
        let origin = @0x1;
        let destination = @0x2;
        initialize_supply_chain(&admin);
        create_shipment(&admin, shipment_id, origin, destination);
        create_shipment(&admin, shipment_id, origin, destination);
    }

    #[test(admin = @supply_chain_program)]
    #[expected_failure(abort_code = E_INVALID_STATUS_UPDATE)]
    public entry fun test_invalid_status_update(admin: signer) acquires ShipmentList {
        let shipment_id = 1;
        let origin = @0x1;
        let destination = @0x2;
        initialize_supply_chain(&admin);
        create_shipment(&admin, shipment_id, origin, destination);
        update_shipment_status(&admin, shipment_id, STATUS_DELIVERED);
    }

    #[test(admin = @supply_chain_program)]
    #[expected_failure(abort_code = E_SHIPMENT_NOT_FOUND)]
    public entry fun test_update_nonexistent_shipment(admin: signer) acquires ShipmentList {
        let shipment_id = 1;
        update_shipment_status(&admin, shipment_id, STATUS_SHIPPING);
    }
}

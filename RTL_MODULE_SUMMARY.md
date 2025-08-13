# NeuronLink NoC RTL Module Summary

This document provides a comprehensive analysis of all RTL modules in the NeuronLink Network-on-Chip (NoC) design, including their roles, interconnections, and locations of arbitration and routing logic.

## Architecture Overview

The NeuronLink NoC implements a mesh-based network architecture with the following hierarchy:
- **Chip Top Level**: System integration with PCIe and NeuronLink-C interfaces
- **NoC Mesh**: 2D mesh network of routers with configurable dimensions (default 4x4)
- **Processing Nodes**: Compute elements with Digital Processing Units (DPUs) and Analog Processing Units (APUs)
- **Network Controllers**: Physical and data link layer protocol handling for NeuronLink-C
- **I/O Interfaces**: PCIe bridge and other system interfaces

---

## Top-Level System Modules

### 1. chip_top.v (110 lines)
**Role**: Main chip-level integration module
**Connections**: 
- Instantiates `noc_mesh_top` (4x4 mesh network)
- Instantiates `processing_node` at each mesh position
- Instantiates `io_bridge` connected to mesh tile [0][0]
- Provides PCIe and NeuronLink-C external interfaces
**Parameters**: Configurable mesh dimensions, data widths, VC counts
**Key Signals**: PCIe data/control, NeuronLink-C serial, local injection/ejection

### 2. noc_mesh_top.v (127 lines)
**Role**: 2D mesh network topology manager
**Connections**:
- Instantiates `neuronlink_router` at each (x,y) coordinate
- Manages inter-router links (North/East/South/West)
- Handles boundary conditions for edge routers
- Provides local injection/ejection interfaces for all tiles
**Architecture**: Parameterized X×Y mesh with 5-port routers (4 directions + local)
**Data Flow**: Flattened local interfaces, unpacked internal mesh connectivity

---

## Router Architecture

### 3. neuronlink_router.v (212 lines) - **MAIN ROUTER MODULE**
**Role**: Core NoC router implementing virtual channel flow control
**Architecture**: 5-port router (N/E/S/W/Local) with VC-based switching
**Key Components**:
- Input VC buffers per port
- Route computation per VC
- VC allocation with hybrid scoring
- Switch allocation with round-robin arbitration
- Output port buffering
- Crossbar switching fabric

**Arbitration Logic Locations**:
- Virtual Channel allocation: `nl_router_vc_allocator` instances
- Switch allocation: `nl_router_switch_allocator` instances  
- Arbitration interception: Uses `nl_router_arb_interception` logic

**Routing Logic**: `nl_router_route_comp` per input VC for destination-based routing

### 4. nl_router_input_port.v (45 lines)
**Role**: Input port management with VC buffer coordination
**Connections**: Interfaces with VC buffers and route computation

### 5. nl_router_output_port.v (58 lines)
**Role**: Output port buffering and flow control
**Connections**: Receives from crossbar, buffers before external output

### 6. nl_router_crossbar_switch.v (34 lines)
**Role**: Data switching fabric
**Connections**: Multiplexes input VCs to output ports based on grants

---

## Arbitration Logic Modules

### 7. nl_router_switch_allocator.v (48 lines) - **ARBITRATION LOGIC**
**Role**: Switch resource allocation with fairness
**Algorithm**: Round-robin arbitration with priority masking
**Key Features**:
- Configurable number of inputs/outputs
- Priority-based request filtering  
- Round-robin pointer advancement
- Single-cycle grant generation

### 8. nl_router_vc_allocator.v (36 lines) - **ARBITRATION LOGIC**
**Role**: Virtual channel allocation with QoS scoring
**Algorithm**: Highest-score-first allocation
**Key Features**:
- Score-based priority (age + congestion weighted)
- Interception-aware masking
- Tie-breaking by lowest index

### 9. nl_router_arb_interception.v (38 lines) - **ARBITRATION LOGIC**
**Role**: Priority inversion prevention for VC allocation
**Algorithm**: Higher-priority VC request monitoring
**Key Features**:
- Prevents lower-priority VCs from blocking higher-priority ones
- Index-based priority ordering (lower index = higher priority)

---

## Routing Decision Logic

### 10. nl_router_route_comp.v (44 lines) - **ROUTING DECISION LOGIC**
**Role**: Packet routing algorithm implementation
**Algorithm**: Odd-Even deadlock-free routing
**Key Features**:
- X-first routing with Y-direction restrictions
- Deadlock avoidance through even/odd column constraints
- Local delivery detection
- 3-bit destination coordinate extraction from header

### 11. nl_router_score_comp.v (27 lines)
**Role**: QoS scoring computation support
**Connections**: Provides scoring inputs to VC allocator

### 12. nl_router_weight_comp.v (28 lines)
**Role**: Weighted scoring for hybrid arbitration
**Algorithm**: Combines age and congestion metrics
**Parameters**: Configurable age and congestion weights

---

## Virtual Channel Buffer Management

### 13. nl_router_input_vc_buffer.v (61 lines)
**Role**: Per-VC input buffering with flow control
**Features**: Configurable depth, ready/valid handshaking

### 14. nl_router_vc_input_buffer.v (62 lines)
**Role**: Alternative VC buffer implementation
**Features**: Similar to input_vc_buffer with different interface

---

## Processing Node Hierarchy

### 15. processing_node.v (121 lines)
**Role**: Compute tile with DPUs, APUs, and memory interfaces
**Components**:
- Multiple DPUs (Digital Processing Units)
- Multiple APUs (Analog Processing Units) 
- Shared bus interconnect
- eDRAM interface
**Data Width**: 32-bit for DPUs/memory, 8-bit for APUs (zero-extended)

### 16. pn_dpu.v (94 lines)
**Role**: Digital Processing Unit implementation
**Features**: 8-bit input processing, 32-bit output generation

### 17. pn_apu.v (39 lines)  
**Role**: Analog Processing Unit interface
**Features**: 8-bit analog-to-digital conversion, memristor interfaces

### 18. pn_shared_bus.v (136 lines)
**Role**: Interconnect between DPUs, APUs, and memory
**Features**: Arbitrated access, configurable DPU/APU counts

### 19. pn_edram_if.v (54 lines)
**Role**: Embedded DRAM interface
**Features**: Read/write control, address/data interfaces

---

## Analog Processing Unit (APU) Components

### 20. apu_internal_bus.v (77 lines)
**Role**: Internal APU interconnect
**Features**: Address/data routing within APU

### 21. apu_adc_if.v (24 lines)
**Role**: Analog-to-Digital Converter interface
**Features**: Digital data output from analog signals

### 22. apu_dac_if.v (26 lines)
**Role**: Digital-to-Analog Converter interface  
**Features**: Analog signal generation from digital inputs

### 23. apu_memristor_xbar_model.v (28 lines)
**Role**: Memristor crossbar behavioral model
**Features**: Neuromorphic compute simulation

### 24. apu_sah_model.v (22 lines)
**Role**: Sample-and-Hold circuit model
**Features**: Analog signal sampling and retention

---

## Network Controller - Transmit Path

### 25. nc_tx_transaction_if.v (63 lines)
**Role**: Transaction layer interface for outgoing packets
**Layer**: Transaction layer (highest)

### 26. nc_tx_dll_packager.v (64 lines)
**Role**: Packet assembly and header generation
**Layer**: Data Link Layer

### 27. nc_tx_dll_packet_analyzer.v (31 lines)
**Role**: Packet analysis and classification
**Layer**: Data Link Layer

### 28. nc_tx_dll_retry_buffer.v (62 lines)
**Role**: Retransmission buffer for reliability
**Layer**: Data Link Layer

### 29. nc_tx_dll_vc_buffers.v (149 lines)
**Role**: Virtual channel buffering for TX path
**Layer**: Data Link Layer

### 30. nc_tx_dll_async_fifo.v (92 lines)
**Role**: Clock domain crossing FIFO
**Layer**: Data Link Layer

### 31. nc_tx_dll_crm.v (98 lines)
**Role**: Credit-based flow control management
**Layer**: Data Link Layer
**Features**: Credit tracking, flow control logic

### 32. nc_tx_pl_cmd_if.v (43 lines)
**Role**: Command interface for physical layer
**Layer**: Physical Layer

### 33. nc_tx_pl_data_if.v (112 lines)
**Role**: Data interface and framing
**Layer**: Physical Layer

### 34. nc_tx_pl_control_field_gen.v (46 lines)
**Role**: Control field generation for packets
**Layer**: Physical Layer

### 35. nc_tx_pl_encoder.v (41 lines)
**Role**: Data encoding (e.g., 8b/10b)
**Layer**: Physical Layer

### 36. nc_tx_pl_scrambler.v (54 lines)
**Role**: Data scrambling for EMI reduction
**Layer**: Physical Layer

### 37. nc_tx_pl_gearbox.v (52 lines)
**Role**: Data width conversion and alignment
**Layer**: Physical Layer

### 38. nc_tx_pl_serializer.v (49 lines)
**Role**: Parallel-to-serial conversion
**Layer**: Physical Layer

---

## Network Controller - Receive Path

### 39. nc_rx_dll_buffer.v (49 lines)
**Role**: Receive buffering at data link layer
**Layer**: Data Link Layer

### 40. nc_rx_dll_crm.v (170 lines)
**Role**: Credit management for RX flow control
**Layer**: Data Link Layer
**Features**: Credit generation, buffer management

### 41. nc_rx_dll_noc_if.v (57 lines)
**Role**: Interface between DLL and NoC
**Layer**: Data Link Layer to NoC Interface

### 42. nc_rx_dll_vc_buffers.v (144 lines)
**Role**: Virtual channel buffering for RX path
**Layer**: Data Link Layer

### 43. nc_rx_pl_cmd_if.v (24 lines)
**Role**: Command interface for RX physical layer
**Layer**: Physical Layer

### 44. nc_rx_pl_data_if.v (23 lines)
**Role**: Data interface for physical layer
**Layer**: Physical Layer

### 45. nc_rx_pl_decoder.v (81 lines)
**Role**: Data decoding (e.g., 8b/10b decode)
**Layer**: Physical Layer

### 46. nc_rx_pl_descrambler.v (38 lines)
**Role**: Data descrambling
**Layer**: Physical Layer

### 47. nc_rx_pl_deserializer.v (37 lines)
**Role**: Serial-to-parallel conversion
**Layer**: Physical Layer

### 48. nc_rx_pl_elastic_buffer.v (47 lines)
**Role**: Clock domain crossing and buffering
**Layer**: Physical Layer

### 49. nc_rx_pl_pma_logic.v (44 lines)
**Role**: Physical Medium Attachment logic
**Layer**: Physical Layer

---

## I/O and Interface Modules

### 50. io_bridge.v (443 lines) - **LARGEST MODULE**
**Role**: System I/O bridge with multiple protocol support
**Interfaces**:
- PCIe interface (64-bit data)
- NoC interface (injection/ejection)
- NeuronLink-C serial interface
**Components**: TX/RX pipeline integration, protocol conversion
**Key Feature**: Connects external interfaces to mesh tile [0][0]

### 51. pcie_interface_logic.v (73 lines)
**Role**: PCIe protocol handling logic
**Features**: PCIe transaction processing

---

## Utility and Test Modules

### 52. fifo.v (47 lines)
**Role**: Generic FIFO buffer implementation
**Features**: Parameterizable depth, standard FIFO interface

### 53. neuronlink_router_fpga_top.v (63 lines)
**Role**: FPGA-specific wrapper for router
**Features**: FPGA testing interface, pin assignments

### 54. fpga_test.v (53 lines)
**Role**: FPGA test harness
**Features**: Test pattern generation, verification support

### 55. led_blinker.v (11 lines)
**Role**: Simple LED control for status indication
**Features**: Basic counter-based LED blinking

---

## Key Arbitration Logic Summary

**Primary Arbitration Locations:**
1. **Switch Allocation**: `nl_router_switch_allocator.v` - Round-robin with priority masking
2. **Virtual Channel Allocation**: `nl_router_vc_allocator.v` - Score-based highest-priority-first
3. **Arbitration Interception**: `nl_router_arb_interception.v` - Priority inversion prevention

**Secondary Arbitration:**
- Credit-based flow control in TX/RX DLL modules
- Shared bus arbitration in `pn_shared_bus.v`

## Key Routing Decision Summary

**Primary Routing Logic:**
1. **Route Computation**: `nl_router_route_comp.v` - Odd-Even deadlock-free routing algorithm

**Routing Algorithm Details:**
- X-Y coordinate extraction from packet header
- Odd-Even column constraints for deadlock avoidance
- Priority: X-direction first, then Y-direction
- Local delivery when destination matches router coordinates

## NoC Hierarchy and Connections

```
chip_top
├── noc_mesh_top (4x4 mesh)
│   └── neuronlink_router[x][y] (16 routers)
│       ├── nl_router_input_port[5] (N/E/S/W/Local)
│       ├── nl_router_vc_allocator[5] (per port)
│       ├── nl_router_switch_allocator[5] (per output)
│       ├── nl_router_route_comp[5×4] (per input VC)
│       ├── nl_router_crossbar_switch
│       └── nl_router_output_port[5]
├── processing_node[16] (one per mesh tile)
│   ├── pn_dpu[2] (per node)
│   ├── pn_apu[2] (per node)
│   ├── pn_shared_bus
│   └── pn_edram_if
└── io_bridge (connected to mesh[0][0])
    ├── PCIe interface
    ├── NeuronLink-C TX/RX pipeline
    └── NoC injection/ejection
```

## Data Flow Summary

1. **External → NoC**: PCIe/NeuronLink-C → io_bridge → mesh[0][0] → routing through mesh
2. **NoC → External**: Mesh routing → mesh[0][0] → io_bridge → PCIe/NeuronLink-C  
3. **Processing**: Local nodes inject/eject at their respective mesh tiles
4. **Routing**: Odd-Even algorithm ensures deadlock-free packet delivery
5. **Arbitration**: Multi-level (VC allocation → Switch allocation) with QoS scoring

This architecture provides a scalable, deadlock-free NoC with hybrid analog-digital processing capabilities and multiple external interface protocols.
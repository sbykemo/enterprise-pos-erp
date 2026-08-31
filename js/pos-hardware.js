/**
 * POS Hardware Integration Layer
 * Supports Web Serial, Web USB, Network printing, Cash Drawer, Pole Display
 */

export class HardwareError extends Error {
    constructor(message, device, operation, originalError = null) {
        super(message);
        this.name = 'HardwareError';
        this.device = device;
        this.operation = operation;
        this.originalError = originalError;
    }
}

export class POSHardware {
    constructor(config = {}) {
        this.config = {
            printerType: config.printerType || 'NETWORK', // 'NETWORK', 'USB', 'SERIAL', 'BLUETOOTH'
            printerIp: config.printerIp || '127.0.0.1',
            printerPort: config.printerPort || 9100,
            usbVendorId: config.usbVendorId || null,
            usbProductId: config.usbProductId || null,
            poleDisplayIp: config.poleDisplayIp || '127.0.0.1',
            poleDisplayPort: config.poleDisplayPort || 9101,
            drawerEnabled: config.drawerEnabled !== false,
        };

        this.printer = {
            connected: false,
            device: null, // USB device or Serial port
        };
        
        this.poleDisplay = {
            connected: false,
            device: null
        };
        
        this.scanner = {
            cleanup: null
        };
        
        this.scale = {
            connected: false,
            port: null
        };
    }

    _dispatchEvent(name, detail = {}) {
        const event = new CustomEvent(name, { detail });
        document.dispatchEvent(event);
    }

    async checkHardwareSupport() {
        return {
            serial: 'serial' in navigator,
            usb: 'usb' in navigator,
            bluetooth: 'bluetooth' in navigator
        };
    }

    getStatus() {
        return {
            printer: this.printer.connected,
            poleDisplay: this.poleDisplay.connected,
            scanner: !!this.scanner.cleanup,
            scale: this.scale.connected
        };
    }

    async reconnectAll() {
        const results = {};
        try {
            await this.connectPrinter();
            results.printer = true;
        } catch (e) { results.printer = false; }
        
        return results;
    }

    // --- Printer ---

    async connectPrinter() {
        try {
            if (this.config.printerType === 'NETWORK') {
                // For network, we usually connect at print time via REST or TCP bridge
                this.printer.connected = true;
                this._dispatchEvent('pos-hardware-connected', { device: 'printer', type: 'NETWORK' });
                return true;
            } else if (this.config.printerType === 'USB') {
                if (!navigator.usb) throw new Error('WebUSB not supported');
                
                let filters = [];
                if (this.config.usbVendorId) {
                    filters.push({ vendorId: this.config.usbVendorId, productId: this.config.usbProductId });
                }
                
                const device = await navigator.usb.requestDevice({ filters });
                await device.open();
                
                if (device.configuration === null) {
                    await device.selectConfiguration(1);
                }
                await device.claimInterface(0);
                
                this.printer.device = device;
                this.printer.connected = true;
                this._dispatchEvent('pos-hardware-connected', { device: 'printer', type: 'USB' });
                return true;
            } else if (this.config.printerType === 'SERIAL') {
                if (!navigator.serial) throw new Error('WebSerial not supported');
                
                const port = await navigator.serial.requestPort();
                await port.open({ baudRate: 9600 });
                
                this.printer.device = port;
                this.printer.connected = true;
                this._dispatchEvent('pos-hardware-connected', { device: 'printer', type: 'SERIAL' });
                return true;
            }
        } catch (error) {
            this.printer.connected = false;
            this._dispatchEvent('pos-hardware-error', { device: 'printer', error: error.message });
            throw new HardwareError('Failed to connect printer', 'printer', 'connect', error);
        }
    }

    async disconnectPrinter() {
        if (!this.printer.connected) return;
        
        try {
            if (this.config.printerType === 'USB' && this.printer.device) {
                await this.printer.device.close();
            } else if (this.config.printerType === 'SERIAL' && this.printer.device) {
                await this.printer.device.close();
            }
            this.printer.device = null;
            this.printer.connected = false;
            this._dispatchEvent('pos-hardware-disconnected', { device: 'printer' });
        } catch (error) {
            console.error('Error disconnecting printer', error);
        }
    }

    isPrinterConnected() {
        return this.printer.connected;
    }

    async printRaw(uint8Array) {
        if (!this.isPrinterConnected()) {
            await this.connectPrinter();
        }

        try {
            if (this.config.printerType === 'NETWORK') {
                // Using a local print agent
                const url = `http://${this.config.printerIp}:${this.config.printerPort}/print`;
                const response = await fetch(url, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/octet-stream' },
                    body: uint8Array
                });
                if (!response.ok) throw new Error(`HTTP ${response.status}`);
            } else if (this.config.printerType === 'USB') {
                // Find endpoint
                let endpointNumber = null;
                for (let intf of this.printer.device.configuration.interfaces) {
                    for (let alt of intf.alternates) {
                        for (let ep of alt.endpoints) {
                            if (ep.direction === 'out') {
                                endpointNumber = ep.endpointNumber;
                                break;
                            }
                        }
                    }
                }
                if (endpointNumber === null) throw new Error('No OUT endpoint found');
                await this.printer.device.transferOut(endpointNumber, uint8Array);
            } else if (this.config.printerType === 'SERIAL') {
                const writer = this.printer.device.writable.getWriter();
                await writer.write(uint8Array);
                writer.releaseLock();
            }
        } catch (error) {
            this._dispatchEvent('pos-hardware-error', { device: 'printer', operation: 'print', error: error.message });
            throw new HardwareError('Failed to print data', 'printer', 'printRaw', error);
        }
    }

    async printReceipt(orderData) {
        if (!window.ESCPOSBuilder) throw new Error('ESCPOSBuilder not loaded');
        const builder = new window.ESCPOSBuilder();
        builder.buildReceipt(orderData);
        await this.printRaw(builder.getBuffer());
    }

    async printXReport(shiftData) {
        if (!window.ESCPOSBuilder) throw new Error('ESCPOSBuilder not loaded');
        const builder = new window.ESCPOSBuilder();
        builder.buildXReport(shiftData);
        await this.printRaw(builder.getBuffer());
    }

    async printZReport(shiftData) {
        if (!window.ESCPOSBuilder) throw new Error('ESCPOSBuilder not loaded');
        const builder = new window.ESCPOSBuilder();
        builder.buildZReport(shiftData);
        await this.printRaw(builder.getBuffer());
    }

    async testPrint() {
        if (!window.ESCPOSBuilder) throw new Error('ESCPOSBuilder not loaded');
        const builder = new window.ESCPOSBuilder();
        builder.init()
            .alignCenter()
            .bold(true).text('TEST PRINT').newline()
            .bold(false).text('Printer Connection OK').newline()
            .feedLines(3).cut();
        await this.printRaw(builder.getBuffer());
    }

    // --- Cash Drawer ---
    
    async openCashDrawer(pin = 2) {
        if (!this.config.drawerEnabled) return;
        if (!window.ESCPOSBuilder) throw new Error('ESCPOSBuilder not loaded');
        const builder = new window.ESCPOSBuilder();
        builder.openDrawer(pin);
        await this.printRaw(builder.getBuffer());
    }

    // --- Pole Display ---
    
    async connectPoleDisplay() {
        // Simplified network connection to local agent
        this.poleDisplay.connected = true;
        this._dispatchEvent('pos-hardware-connected', { device: 'poleDisplay' });
        return true;
    }

    async displayOnPole(line1, line2 = '') {
        if (!this.poleDisplay.connected) return;
        try {
            const url = `http://${this.config.poleDisplayIp}:${this.config.poleDisplayPort}/display`;
            await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ line1: line1.substring(0, 20), line2: line2.substring(0, 20) })
            });
        } catch (e) {
            console.warn('Pole display error', e);
        }
    }

    async displayTotal(amount) {
        await this.displayOnPole('TOTAL:', `SAR ${Number(amount).toFixed(2)}`);
    }

    async displayWelcome() {
        await this.displayOnPole('Welcome to', 'Our Store!');
    }

    async clearPoleDisplay() {
        await this.displayOnPole('', '');
    }

    // --- Barcode Scanner (Keyboard Wedge) ---
    
    initBarcodeListener(callback) {
        let buffer = '';
        let lastTime = Date.now();
        
        const keydownHandler = (e) => {
            const now = Date.now();
            const timeDiff = now - lastTime;
            lastTime = now;
            
            // Typical scanner types chars very fast (< 50ms between strokes)
            if (timeDiff > 50) {
                buffer = '';
            }
            
            if (e.key === 'Enter' && buffer.length > 3) {
                const barcode = buffer;
                buffer = '';
                
                this._dispatchEvent('pos-barcode-scanned', { barcode, source: 'wedge' });
                if (typeof callback === 'function') {
                    callback(barcode);
                }
            } else if (e.key.length === 1) {
                buffer += e.key;
            }
        };
        
        document.addEventListener('keydown', keydownHandler);
        
        this.scanner.cleanup = () => {
            document.removeEventListener('keydown', keydownHandler);
            this.scanner.cleanup = null;
        };
        
        return this.scanner.cleanup;
    }

    async connectSerialScanner() {
        if (!navigator.serial) throw new Error('WebSerial not supported');
        
        try {
            const port = await navigator.serial.requestPort();
            await port.open({ baudRate: 9600 });
            // Implementation for reading from serial stream...
            return true;
        } catch (error) {
            throw new HardwareError('Failed to connect serial scanner', 'scanner', 'connect', error);
        }
    }

    // --- Scale Integration ---

    async connectScale() {
        if (!navigator.serial) throw new Error('WebSerial not supported');
        try {
            const port = await navigator.serial.requestPort();
            await port.open({ baudRate: 9600 });
            this.scale.port = port;
            this.scale.connected = true;
            this._dispatchEvent('pos-hardware-connected', { device: 'scale' });
            return true;
        } catch (error) {
            this.scale.connected = false;
            throw new HardwareError('Failed to connect scale', 'scale', 'connect', error);
        }
    }

    async readWeight() {
        if (!this.scale.connected) throw new Error('Scale not connected');
        // Mock implementation for reading from serial scale
        return { value: 0, unit: 'kg' };
    }
}

// Export to window
if (typeof window !== 'undefined') {
    window.POSHardware = POSHardware;
    window.HardwareError = HardwareError;
}

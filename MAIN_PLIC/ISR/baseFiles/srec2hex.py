import sys

def convert_srecord_to_custom_format(srecord_data):
    lines = srecord_data.split('\n')
    output = []
    address = None
    data = ""
    for line in lines:
        line = line.strip()
        if line.startswith('S1') or line.startswith('S2') or line.startswith('S3'):
            byte_count = int(line[2:4], 16)
            address = int(line[4:8], 16)+1
            data = line[8:-2]
            for i in range(0, (byte_count-3)*2, 2):
                output.append(f"mem[{address}]<= 8'h{data[i:i+2]};")
                # output.append(f"{address}: {data[i:i+2]};")
                # output.append(f"{data[i:i+2]}")
                address += 1
        elif line.startswith('S7') or line.startswith('S8') or line.startswith('S9'):
            break
    return '\n'.join(output)

def main():
    if len(sys.argv) != 2:
        print("Usage: python srecord_to_hex.py <filename>")
        return
    
    filename = sys.argv[1]

    try:
        with open(filename, 'r') as file:
            srecord_data = file.read()
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found.")
        return

    custom_format_data = convert_srecord_to_custom_format(srecord_data)

    output_filename = filename.rsplit('.', 1)[0] + ".hex"
    with open(output_filename, 'w') as file:
        file.write(custom_format_data)
    
    print(f"Conversion complete. Output written to '{output_filename}'.")

if __name__ == "__main__":
    main()

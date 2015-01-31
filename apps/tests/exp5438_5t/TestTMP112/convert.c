#include <stdio.h>

double
celsiusToFahrenheit(double d) {
	return (d * 1.8) + 32.0;
}

// buf must be at least ('length' * 9) + 1 chars long
char *
bitsToString(char *data, int length, char *buf) {
	char *bp=buf;
	
	unsigned char mask = 0x01;
	int ptr = 0;
	int bit = 0;
	for(;ptr < length;ptr++) {
		for(bit = 7; bit >= 0; bit--) {
			if ((mask << bit) & (unsigned char)*(data+ptr)) 
				*bp++ = '1';	
			else 
				*bp++ = '0';			
		}
		*bp++ = ' ';
	}
	*bp = '\0';
	return buf;
}

void
bitPrint(char* data, int length)
{
	char buf[10];
	
	int ptr = 0;
	for(;ptr < length;ptr++) {
		printf("%s ", bitsToString(data+ptr, 1, buf));
	}
}

int main0 (int argc, const char * argv[]) {
	unsigned w = 4;
	printf("w =                   %6d  %x  ", w, w);
	bitPrint((char *)&w, 2);
	printf("\n");
	
	w ^= 0xFFFF;
	printf("ones complement =     %6d  %6x  ", w, w);
	bitPrint((char *)&w, 2);
	printf("\n");

	w += 1;
	printf("twos complement =     %6d  %6x  ", w, w);
	bitPrint((char *)&w, 2);
	printf("\n");

    printf("Now go back...\n");
	w ^= 0xFFFF;
	w += 1;
	printf("twos complement of the twos complement =     %6d  %6x  ", w, w);
	bitPrint((char *)&w, 2);
	printf("\n");
    return 0;
}


int main(int argc, const char * argv[]) {
	// first byte is the MSB
	unsigned char data[2];

	// examples:
	// 7f, f0 -> 127.9
	// 50, 00 -> 80
	data[0] = 0x16;
	data[1] = 0xff; 
	
		// positive
		unsigned temp0 = data[0];
		temp0 = temp0 << 4;
		
		// second is the LSB
		temp0 |=  data[1] >> 4;
		
		printf("temp0 = %x\n", temp0);
		
		printf("temperature = %g C  %g F\n", (temp0 * 0.0625), celsiusToFahrenheit(temp0 * 0.0625));
}




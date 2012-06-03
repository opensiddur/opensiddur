// Simple Base64 encoder/decoder
// Public Domain

Base64 = {

	encode : function (input) {
		// Converts each character in the input to its Unicode number, then writes
		// out the Unicode numbers in binary, one after another, into a string.
		// This string is then split up at every 6th character, these substrings
		// are then converted back into binary integers and are used to subscript
		// the "swaps" array.
		// Since this would create HUGE strings of 1s and 0s, the distinct steps
		// above are actually interleaved in the code below (ie. the long binary
		// string, called "input_binary", gets processed while it is still being
		// created, so that it never gets too big (in fact, it stays under 13
		// characters long no matter what).

		// The indices of this array provide the map from numbers to base 64
		var swaps = ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","0","1","2","3","4","5","6","7","8","9","+","/"];
		var input_binary = "";		// The input string, converted to Unicode numbers and written out in binary
		var output = "";		// The base 64 output
		var temp_binary;		// Used to ensure the binary numbers have 8 bits
		var index;		// Loop variable, for looping through input
		for (index=0; index < input.length; index++)
		{
			// Turn the next character of input into astring of 8-bit binary
			temp_binary = input.charCodeAt(index).toString(2);
			while (temp_binary.length < 8)
			{
				temp_binary = "0"+temp_binary;
			}
			// Stick this string on the end of the previous 8-bit binary strings to
			// get one big concatenated binary representation
			input_binary = input_binary + temp_binary;
			// Remove all 6-bit sequences from the start of the concatenated binary
			// string, convert them to a base 64 character and append to output.
			// Doing this here prevents input_binary from getting massive
			while (input_binary.length >= 6)
			{
				output = output + swaps[parseInt(input_binary.substring(0,6),2)];
				input_binary = input_binary.substring(6);
			}
		}
		// Handle any necessary padding
		if (input_binary.length == 4)
		{
			temp_binary = input_binary + "00";
			output = output + swaps[parseInt(temp_binary,2)];
			output = output + "=";
		}
		if (input_binary.length == 2)
		{
			temp_binary = input_binary + "0000";
			output = output + swaps[parseInt(temp_binary,2)];
			output = output + "==";
		}
		// Output now contains the input in base 64
		return output;
	},

	decode : function (input) {
		// Takes a base 64 encoded string "input", strips any "=" or "==" padding
		// off it and converts its base 64 numerals into regular integers (using a
		// string as a lookup table). These are then written out as 6-bit binary
		// numbers and concatenated together. The result is split into 8-bit
		// sequences and these are converted to string characters, which are
		// concatenated and output.
		input = input.replace("=","");		// Padding characters are redundant
		// The index/character relationship in the following string acts as a
		// lookup table to convert from base 64 numerals to Javascript integers
		var swaps = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
		var output_binary = "";
		var output = "";
		var temp_bin = "";
		var index;
		for (index=0; index < input.length; index++)
		{
			temp_bin = swaps.indexOf(input.charAt(index)).toString(2);
			while (temp_bin.length < 6)
			{
				// Add significant zeroes
				temp_bin = "0"+temp_bin;
			}
			while (temp_bin.length > 6)
			{
				// Remove significant bits
				temp_bin = temp_bin.substring(1);
			}
			output_binary = output_binary + temp_bin;
			while (output_binary.length >= 8)
			{
				output = output + String.fromCharCode(parseInt(output_binary.substring(0,8),2));
				output_binary = output_binary.substring(8);
			}
		}
		return output;
	}

};


#include <stdio.h>

int main(int argc, char **argv)
{
	int i = 0;
	char *str="abc÷–";

	while (str[i])
	{
		printf("%02x ", str[i]);
		i++;
	}
	printf("\n");
	printf("%s\n", str);

	return 0;
}

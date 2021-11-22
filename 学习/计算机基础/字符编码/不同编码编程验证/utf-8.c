#include <stdio.h>

int main()
{
    char *str = "abc中";
    int i = 0;
    
    while(str[i])
    {
        printf("%02x ", str[i]);
        i++;
    }

    return 0;
}

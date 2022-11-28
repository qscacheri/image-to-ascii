//
//  Shaders.metal
//  Image2Ascii
//
//  Created by Quin Scacheri on 11/26/22.
//

#include <metal_stdlib>
using namespace metal;


kernel void image2Ascii(
                          texture2d<float, access::sample> imageTexture [[texture(0)]],
                          device char *ascii [[buffer(0)]],
                          uint2 gridPosition [[thread_position_in_grid]]
                          
                      )
{
    
    int asciiIndex = (imageTexture.get_width() + 1) * gridPosition.y + gridPosition.x;
   
    if (gridPosition.x == imageTexture.get_width()) {
        if (gridPosition.y == imageTexture.get_height() - 1) {
            ascii[asciiIndex] = '\0';
        }
        else {
            ascii[asciiIndex] = '\n';
        }
    }
    else {
        float4 color = imageTexture.read(gridPosition);
        float greyScale = color.r * 0.21 + color.g * 0.72 * color.b * 0.07;
        char colors[] = "$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/|()1{}[]?-_+~<>i!lI;:,\"^`'. ";
        int colorIndex = ceil(greyScale * 71);
        ascii[asciiIndex] = colors[colorIndex];
    }
}

#ifndef OV5640_CONFIG_H
#define OV5640_CONFIG_H

#define P1080 0


#if P1080 == 1
#define VIDEO_COLUMNS 1920
#define VIDEO_ROWS 1080
#else
#define VIDEO_COLUMNS 1280
#define VIDEO_ROWS 720
#endif

#endif /* OV5640_CONFIG_H */


#ifndef OV5640_CONFIG_H
#define OV5640_CONFIG_H

#define P1080 1

#if P1080 == 1
#define VIDEO_COLUMNS 1920
#define VIDEO_ROWS 1080
#else
#define VIDEO_COLUMNS 1280
#define VIDEO_ROWS 720
#endif

/* N12 S3 winner: Y+1 lowers 2px checker energy (vflip Bayer phase) */
#ifndef BAYER_X_OFF
#define BAYER_X_OFF 0
#endif
#ifndef BAYER_Y_OFF
#define BAYER_Y_OFF 1
#endif

#endif /* OV5640_CONFIG_H */

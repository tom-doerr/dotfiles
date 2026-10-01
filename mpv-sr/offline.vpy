# Offline 2x RGB or luma model. user-data = "<rgb|pad|luma>|<engine path>".
import vapoursynth as vs

core = vs.core
mode, engine = user_data.split('|', 1)
clip = video_in
w, h = clip.width, clip.height
fmt = vs.RGBS if '.fp32.' in engine else vs.RGBH
if mode == 'luma':
    y = core.resize.Bicubic(core.std.ShufflePlanes(clip, 0, vs.GRAY),
                            format=vs.GRAYH, range_in_s='limited', range_s='full')
    y = core.trt.Model([y], engine_path=engine)
    y = core.resize.Bicubic(y, format=vs.GRAY16, range_in_s='full', range_s='limited')
    c = core.resize.Spline36(clip, w * 2, h * 2, format=vs.YUV444P16)
    out = core.std.ShufflePlanes([y, c], [0, 1, 2], vs.YUV)
    out = core.resize.Point(out, format=vs.YUV444P10, dither_type='error_diffusion')
else:
    if mode not in ('rgb', 'pad'):
        raise ValueError(f'Unknown mode: {mode}')
    rgb = core.resize.Bicubic(clip, format=fmt, matrix_in_s='709')
    if mode == 'pad':
        px, py = 960 - w, 540 - h
        if not (0 <= px <= w and 0 <= py <= h):
            raise ValueError('Mirror padding needs input within 480..960 x 270..540')
        if px:
            rgb = core.std.StackHorizontal([
                rgb, core.std.Crop(core.std.FlipHorizontal(rgb), right=w - px)])
        if py:
            rgb = core.std.StackVertical([
                rgb, core.std.Crop(core.std.FlipVertical(rgb), bottom=h - py)])
    rgb = core.trt.Model([rgb], engine_path=engine)
    if mode == 'pad':
        rgb = core.std.Crop(rgb, right=rgb.width - w * 2, bottom=rgb.height - h * 2)
    out = core.resize.Bicubic(rgb, format=vs.YUV444P10, matrix_s='709',
                              dither_type='error_diffusion')
out.set_output()

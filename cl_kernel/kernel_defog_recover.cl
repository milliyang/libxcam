/*
 * function:    kernel_defog_recover
 * input_dark: dark channel image2d_t as read only
 * max_v:       atmospheric light
 * input_r:      R channel image2d_t as read only
 * input_g:     G channel image2d_t as read only
 * input_b:     B channel image2d_t as read only
 * output_y:   Y channel image2d_t as write only
 * output_uv: uv channel image2d_t as write only
 *
 * data_type        CL_UNSIGNED_INT16
 * channel_order  CL_RGBA
 */

#define transmit_map_coeff 0.95f

__kernel void kernel_defog_recover (
    __read_only image2d_t input_dark, float max_v, float max_r, float max_g, float max_b,
    __read_only image2d_t input_r, __read_only image2d_t input_g, __read_only image2d_t input_b,
    __write_only image2d_t out_y, __write_only image2d_t output_uv)
{
    int g_id_x = get_global_id (0);
    int g_id_y = get_global_id (1);
    int pos_x = g_id_x;
    int pos_y = g_id_y * 2;
    sampler_t sampler = CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST;
    float8 in_r[2], in_g[2], in_b[2];
    float8 transmit_map[2];
    float8 out_data;

    in_r[0] = convert_float8(as_uchar8(convert_ushort4(read_imageui(input_r, sampler, (int2)(pos_x, pos_y))))) / 255.0f;
    in_r[1] = convert_float8(as_uchar8(convert_ushort4(read_imageui(input_r, sampler, (int2)(pos_x, pos_y + 1))))) / 255.0f;
    in_g[0] = convert_float8(as_uchar8(convert_ushort4(read_imageui(input_g, sampler, (int2)(pos_x, pos_y))))) / 255.0f;
    in_g[1] = convert_float8(as_uchar8(convert_ushort4(read_imageui(input_g, sampler, (int2)(pos_x, pos_y + 1))))) / 255.0f;
    in_b[0] = convert_float8(as_uchar8(convert_ushort4(read_imageui(input_b, sampler, (int2)(pos_x, pos_y))))) / 255.0f;
    in_b[1] = convert_float8(as_uchar8(convert_ushort4(read_imageui(input_b, sampler, (int2)(pos_x, pos_y + 1))))) / 255.0f;
    transmit_map[0] = convert_float8(as_uchar8(convert_ushort4(read_imageui(input_dark, sampler, (int2)(pos_x, pos_y)))));
    transmit_map[1] = convert_float8(as_uchar8(convert_ushort4(read_imageui(input_dark, sampler, (int2)(pos_x, pos_y + 1)))));

    transmit_map[0] = 1.0f - transmit_map_coeff * transmit_map[0] / max_v;
    transmit_map[1] = 1.0f - transmit_map_coeff * transmit_map[1] / max_v;

    transmit_map[0] = max (transmit_map[0], 0.1f);
    transmit_map[1] = max (transmit_map[1], 0.1f);

//#if 0
    in_r[0] = max_r + (in_r[0] - max_r) / transmit_map[0];
    in_r[1] = max_r + (in_r[1] - max_r) / transmit_map[1];
    in_g[0] = max_g + (in_g[0] - max_g) / transmit_map[0];
    in_g[1] = max_g + (in_g[1] - max_g) / transmit_map[1];
    in_b[0] = max_b + (in_b[0] - max_b) / transmit_map[0];
    in_b[1] = max_b + (in_b[1] - max_b) / transmit_map[1];
//#endif
    out_data = 0.299f * in_r[0] + 0.587f * in_g[0] + 0.114f * in_b[0];
    out_data = clamp (out_data, 0.0f, 1.0f);
    write_imageui(out_y, (int2)(pos_x, pos_y), convert_uint4(as_ushort4(convert_uchar8(out_data * 255.0f))));
    out_data = clamp (out_data, 0.0f, 1.0f);
    out_data = 0.299f * in_r[1] + 0.587f * in_g[1] + 0.114f * in_b[1];
    write_imageui(out_y, (int2)(pos_x, pos_y + 1), convert_uint4(as_ushort4(convert_uchar8(out_data * 255.0f))));

    float4 r, g, b;
    r = (in_r[0].even + in_r[0].odd + in_r[1].even + in_r[1].odd) * 0.25f;
    g = (in_g[0].even + in_g[0].odd + in_g[1].even + in_g[1].odd) * 0.25f;
    b = (in_b[0].even + in_b[0].odd + in_b[1].even + in_b[1].odd) * 0.25f;
    out_data.even = (-0.169f * r - 0.331f * g + 0.5f * b) + 0.5f;
    out_data.odd = (0.5f * r - 0.419f * g - 0.081f * b) + 0.5f;
    out_data = clamp (out_data, 0.0f, 1.0f);
    write_imageui(output_uv, (int2)(g_id_x, g_id_y), convert_uint4(as_ushort4(convert_uchar8(out_data * 255.0f))));
}


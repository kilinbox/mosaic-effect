obs = obslua
bit = require('bit')

SHADER = [[
uniform float4x4 ViewProj;
uniform texture2d image;

uniform int width_pixcel_size;
uniform int height_pixcel_size;
uniform float start_x_offset;
uniform float end_x_offset;
uniform float start_y_offset;
uniform float end_y_offset;

sampler_state textureSampler {
    Filter    = Linear;
    AddressU  = Clamp;
    AddressV  = Clamp;
};

struct VertDataIn {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

struct VertDataOut {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

VertDataOut VShader(VertDataIn v_in)
{
    VertDataOut vert_out;
    vert_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    vert_out.uv  = v_in.uv;
    return vert_out;
}

float4 PShader(VertDataOut v_in) : TARGET
{
    float2 uv_delta = float2(ddx(v_in.uv.x), ddy(v_in.uv.y));
    float2 uv_size = 1.0 / uv_delta;

    float targetWidth = max(2.0, width_pixcel_size);
    float targetHeight = max(2.0, height_pixcel_size);
    const float PI = 3.14159265f;
    float2 tex1;
    int pixelSizeX = int(uv_size.x / targetWidth);
    int pixelSizeY = int(uv_size.y / targetHeight);

    int pixelX = int(v_in.uv.x * uv_size.x);
    int pixelY = int(v_in.uv.y * uv_size.y);

    tex1.x = (((pixelX / pixelSizeX)*pixelSizeX) / uv_size.x) + (pixelSizeX / uv_size.x)/2;
    tex1.y = (((pixelY / pixelSizeY)*pixelSizeY) / uv_size.y) + (pixelSizeY / uv_size.y)/2;

    float4 c1 = image.Sample(textureSampler, v_in.uv);
if ((v_in.uv.x < end_x_offset) && (v_in.uv.x > start_x_offset) &&
    (v_in.uv.y < end_y_offset) && (v_in.uv.y > start_y_offset))
    {
        c1 = image.Sample(textureSampler, tex1 );
    }
    return c1;
}

technique Draw
{
    pass
    {
        vertex_shader = VShader(v_in);
        pixel_shader  = PShader(v_in);
    }
}
]]

source_def = {}
source_def.id = 'mosaic-effect'
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = bit.bor(obs.OBS_SOURCE_VIDEO)

source_def.get_name = function()
    return 'モザイク'
end

function set_render_size(filter)
    target = obs.obs_filter_get_target(filter.context)
  
    local width, height
  if target == nil then
  width = 0
  height = 0
  else
  width = obs.obs_source_get_base_width(target)
  height = obs.obs_source_get_base_height(target)
end

filter.width = width
filter.height = height
width = width == 0 and 1 or width
height = height == 0 and 1 or height
end

source_def.create = function(settings, source)
    filter = {}
    filter.params = {}
    filter.context = source

    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(SHADER, nil, nil)
    if filter.effect ~= nil then
        filter.params.width_pixcel_size = obs.gs_effect_get_param_by_name(filter.effect, 'width_pixcel_size')
        filter.params.height_pixcel_size = obs.gs_effect_get_param_by_name(filter.effect, 'height_pixcel_size')
        filter.params.start_x_offset = obs.gs_effect_get_param_by_name(filter.effect, 'start_x_offset')
        filter.params.end_x_offset = obs.gs_effect_get_param_by_name(filter.effect, 'end_x_offset')
        filter.params.start_y_offset = obs.gs_effect_get_param_by_name(filter.effect, 'start_y_offset')
        filter.params.end_y_offset = obs.gs_effect_get_param_by_name(filter.effect, 'end_y_offset')
    end
    obs.obs_leave_graphics()
    
    if filter.effect == nil then
        source_def.destroy(filter)
        return nil
    end

    source_def.update(filter, settings)
        filter.width_pixcel_size = obs.obs_data_get_int(settings, 'width_pixcel_size')
        filter.height_pixcel_size = obs.obs_data_get_int(settings, 'height_pixcel_size')
        filter.start_x_offset = obs.obs_data_get_double(settings, 'start_x_offset')
        filter.end_x_offset = obs.obs_data_get_double(settings, 'end_x_offset')
        filter.start_y_offset = obs.obs_data_get_double(settings, 'start_y_offset')
        filter.end_y_offset = obs.obs_data_get_double(settings, 'end_y_offset')
    return filter
end

source_def.destroy = function(filter)
    if filter.effect ~= nil then
        obs.obs_enter_graphics()
        obs.gs_effect_destroy(filter.effect)
        obs.obs_leave_graphics()
    end
end

source_def.get_width = function(filter)
    return filter.width
end

source_def.get_height = function(filter)
    return filter.height
end

source_def.update = function(filter, settings)
    filter.width_pixcel_size = obs.obs_data_get_int(settings, "width_pixcel_size")
    filter.height_pixcel_size = obs.obs_data_get_int(settings, "height_pixcel_size")
    filter.start_x_offset = obs.obs_data_get_double(settings, "start_x_offset")
    filter.end_x_offset = obs.obs_data_get_double(settings, "end_x_offset")
    filter.start_y_offset = obs.obs_data_get_double(settings, "start_y_offset")
    filter.end_y_offset = obs.obs_data_get_double(settings, "end_y_offset")
    set_render_size(filter)
end

source_def.video_render = function(filter, effect)
    obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)
    obs.gs_effect_set_int(filter.params.width_pixcel_size, filter.width_pixcel_size)
    obs.gs_effect_set_int(filter.params.height_pixcel_size, filter.height_pixcel_size)
    obs.gs_effect_set_float(filter.params.start_x_offset, filter.start_x_offset)
    obs.gs_effect_set_float(filter.params.end_x_offset, filter.end_x_offset)
    obs.gs_effect_set_float(filter.params.start_y_offset, filter.start_y_offset)
    obs.gs_effect_set_float(filter.params.end_y_offset, filter.end_y_offset)
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

function script_description()
  return 'モザイクエフェクトフィルタをかける'
end

function script_update(settings)
    width_pixcel_size = obs.obs_data_get_int(settings, "width_pixcel_size")
    height_pixcel_size = obs.obs_data_get_int(settings, "height_pixcel_size")
    start_x_offset = obs.obs_data_get_double(settings, "start_x_offset")
    end_x_offset = obs.obs_data_get_double(settings, "end_x_offset")
    start_y_offset = obs.obs_data_get_double(settings, "start_y_offset")
    end_y_offset = obs.obs_data_get_double(settings, "end_y_offset")
end

source_def.get_properties = function(settings)
  props = obs.obs_properties_create()
    obs.obs_properties_add_int_slider(props, "width_pixcel_size", "1ピクセルあたりの横幅", 0, 300, 1)
    obs.obs_properties_add_int_slider(props, "height_pixcel_size", "1ピクセルあたりの縦幅", 0, 300, 1)
    obs.obs_properties_add_float_slider(props, "start_x_offset", "横軸(X)開始位置", 0.0, 1, 0.01)
    obs.obs_properties_add_float_slider(props, "end_x_offset", "横軸(X)終了位置", 0.0, 1, 0.01)
    obs.obs_properties_add_float_slider(props, "start_y_offset", "縦軸(Y)開始位置", 0.0, 1, 0.01)
    obs.obs_properties_add_float_slider(props, "end_y_offset", "縦軸(Y)終了位置", 0.0, 1, 0.01)
    return props
end

source_def.get_defaults = function(settings)
    obs.obs_data_set_default_int(settings, "width_pixcel_size", 50)
    obs.obs_data_set_default_int(settings, "height_pixcel_size", 50)
    obs.obs_data_set_default_double(settings, "start_x_offset", 0)
    obs.obs_data_set_default_double(settings, "end_x_offset", 1)
    obs.obs_data_set_default_double(settings, "start_y_offset", 0)
    obs.obs_data_set_default_double(settings, "end_y_offset", 1)
end

source_def.video_tick = function(filter, seconds)
  set_render_size(filter)
end

obs.obs_register_source(source_def)

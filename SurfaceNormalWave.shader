Shader "Unlit/SurfaceNormalWave" {

    Properties {
        base_color ("Base Color", Color) = (0,0,0,1)
        wave_color ("Wave Color", Color) = (0,0,0,1)
        wave_speed ("Wave Speed", Range (1, 8)) = 4
        edge_hardness ("Edge Hardness", Range (0, 0.05)) = 0.01
        wake_drop_off ("Wake Drop Off", Range (1, 10)) = 5
    }

    SubShader {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass {

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            // IO
            struct vert_input {
                float4 model_pos : POSITION;
                float3 model_normal : NORMAL;
            };

            struct v2f {
                float4 clip_pos : SV_POSITION;
                float3 world_normal : TEXCOORD;
            };

            // User Parameters
            fixed4 base_color;
            fixed4 wave_color;
            int wave_speed;
            float edge_hardness;
            int wake_drop_off;


            // ======= Helpers for points on object. ============

            /*
                Given v2f, compute the distance from the center of the orb to this pixel. Normalized [0, 1]. Its apparent clipping distance.
                Center is 0. Edge is 1.
                Returns -1 for degrees greater than 90.
            */
            float get_normalized_distance_from_center(v2f i){

                float3 object_world_pos = transpose(unity_ObjectToWorld)[3].xyz;
                float3 camera_world_pos = _WorldSpaceCameraPos;

                float3 object_to_camera_normalized = normalize(camera_world_pos - object_world_pos);

                // Compute the angle between the vectors: (1) object anchor to camera. (2) pixel's world normal.
                // Range: [-1, 1] and is = cos(theta)
                float dotp = dot(object_to_camera_normalized, normalize(i.world_normal));
                // Range: [0, 180]
                float angle_degrees = degrees(acos(dotp));

                return angle_degrees > 90 ? -1 : angle_degrees / 90;
            }

            // ======= Helpers for wave. ============
            float get_wave_speed(){
                return _Time.y * wave_speed;
            }

            // Returns the wave position in range [0, 1]
            float get_wave_pos_normalized(){

                // sin() returns [-1, 1]. Oscillate between [0, 1] instead.
                // Convert that to angle. asin() returns [0, pi/2].
                // Convert to degrees, and normalize.
                float angle_radians = asin(abs(sin(get_wave_speed())));
                return degrees(angle_radians) / 90;
            }

            // return_value >= 0 if the wave is going out, return_value < 0 otherwise.
            bool get_wave_going_out(){
                // Period of this sine wave must be half the period of the wave position.
                return sin(get_wave_speed() * 2) >= 0;
            }


            // Main
            v2f vert (vert_input v) {

                v2f o;
                o.clip_pos = UnityObjectToClipPos(v.model_pos);
                // Normalizing before interpolation causes a loss of precision. Don't do it here!
                o.world_normal = mul(unity_ObjectToWorld, float4(v.model_normal, 0));
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {

                // These are [0, 1]
                // Our normalized position from center.
                float pixel_pos = get_normalized_distance_from_center(i);
                // Wave normalized position from center
                float wave_pos = get_wave_pos_normalized();

                bool is_wave_going_out = get_wave_going_out();
                bool is_wave_closer_to_center = wave_pos < pixel_pos;

                // In range: [0, 2]
                // Time since the wave last passed through this pixel.
                // Proportional to the ground the wave covered since it last touched us.
                float rel_time_since_touch;

                if(is_wave_going_out){
                    if(is_wave_closer_to_center){
                        // Wave is closer to center, moving toward us.
                        rel_time_since_touch = pixel_pos + wave_pos;
                    }
                    else{
                        // Wave is farther out, moving away from us.
                        rel_time_since_touch = wave_pos - pixel_pos;
                    }
                }
                else{
                    if(is_wave_closer_to_center){
                        // Wave is closer to center, moving away from us.
                        rel_time_since_touch = pixel_pos - wave_pos;
                    }
                    else{
                        // Wave is farther out, moving toward us.

                        // Distance from center --->
                        /* center     pix_p     <-wave_p     edge
                           |             ********************|     plus
                           |                      ***********|     = Covered ground  */
                        rel_time_since_touch = (1 - pixel_pos) + (1 - wave_pos);
                    }
                }

                float rel_time_since_touch_normalized = rel_time_since_touch / 2;
                float wave_intensity = 1 - rel_time_since_touch_normalized;
                if(rel_time_since_touch_normalized >= edge_hardness){
                    // Find more efficient way.
                    wave_intensity = pow(wave_intensity, wake_drop_off);
                }

                return base_color + (wave_color * wave_intensity);
            } // frag

            ENDCG
        } // pass
    }
}

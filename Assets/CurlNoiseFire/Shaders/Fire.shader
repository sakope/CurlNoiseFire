Shader "Custom/Fire"
{
    Properties
    {
	    _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
    }
    CGINCLUDE
        #define EPSILON 1e-3

        #include "UnityCG.cginc"
        #include "SimplexNoise3D.hlsl"

        struct FireParams
        {
            float3 emitPos;
            float3 position;
            float4 velocity; //xyz = velocity, w = velocity coef
            float3 life;     // x = time elapsed, y = life time, z = isActive 1 is active, -1 is disactive
            float3 size;     // x = current size, y = start size, z = target size.
            float4 color;
            float4 startColor;
            float4 endColor;
        };

        StructuredBuffer<FireParams> buf;

        sampler2D _MainTex;
        float4x4  modelMatrix;

        float3 curlNoise(float3 coord)
        {
            float3 dx = float3(EPSILON, 0.0, 0.0);
            float3 dy = float3(0.0, EPSILON, 0.0);
            float3 dz = float3(0.0, 0.0, EPSILON);

            float3 dpdx0 = snoise(coord - dx);
            float3 dpdx1 = snoise(coord + dx);
            float3 dpdy0 = snoise(coord - dy);
            float3 dpdy1 = snoise(coord + dy);
            float3 dpdz0 = snoise(coord - dz);
            float3 dpdz1 = snoise(coord + dz);

            float x = dpdy1.z - dpdy0.z + dpdz1.y - dpdz0.y;
            float y = dpdz1.x - dpdz0.x + dpdx1.z - dpdx0.z;
            float z = dpdx1.y - dpdx0.y + dpdy1.x - dpdy0.x;

            return float3(x, y, z) / EPSILON * 2.0;
        }

        struct appdata
        {
            float4 vertex : position;
            float2 uv : texcoord0;
        };

        struct v2g
        {
            float4 pos : sv_position;
            float4 col : color;
            float size : texcoord1;
        };

        struct g2f
        {
            float4 pos : sv_position;
            float4 col : color;
            float2 uv  : texcoord0;
        };

        v2g vert(appdata v, uint id: SV_VertexID)
        {
            v2g o;

            FireParams p = buf[id];

            o.pos = mul(modelMatrix, float4(p.position, 1));
            o.col = p.color;
            o.size = p.size.x;

            return o;
        }

        [maxvertexcount(4)]
        void geom(point v2g input[1], inout TriangleStream<g2f> outStream)
        {
            g2f output;
            float3 up = float3(0, 1, 0);
            float3 forward = _WorldSpaceCameraPos - input[0].pos;
            forward.y = 0;
            forward = normalize(forward);
            float3 right = cross(up, forward);

            float halfS = 0.5 * input[0].size.x;

            float4 v[4];
            v[0] = float4(input[0].pos + halfS * right - halfS * up, 1.0);
            v[1] = float4(input[0].pos + halfS * right + halfS * up, 1.0);
            v[2] = float4(input[0].pos - halfS * right - halfS * up, 1.0);
            v[3] = float4(input[0].pos - halfS * right + halfS * up, 1.0);

            output.pos = mul(UNITY_MATRIX_VP, v[0]);
            output.uv = float2(1.0, 0.0);
            output.col = input[0].col;
            outStream.Append(output);

            output.pos = mul(UNITY_MATRIX_VP, v[1]);
            output.uv = float2(1.0, 1.0);
            output.col = input[0].col;
            outStream.Append(output);

            output.pos = mul(UNITY_MATRIX_VP, v[2]);
            output.uv = float2(0.0, 0.0);
            output.col = input[0].col;
            outStream.Append(output);

            output.pos = mul(UNITY_MATRIX_VP, v[3]);
            output.uv = float2(0.0, 1.0);
            output.col = input[0].col;
            outStream.Append(output);

            outStream.RestartStrip();
        }
			
        fixed4 frag (g2f i) : SV_Target
		{
            fixed4 col = tex2D(_MainTex, i.uv) * i.col;
            return col;
        }
        ENDCG

	SubShader
	{
	    Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "PreviewType"="Plane" }
	    Blend SrcAlpha OneMinusSrcAlpha
	    Cull Off Lighting Off ZWrite Off
		Pass
		{
			CGPROGRAM
                #pragma vertex vert
                #pragma geometry geom
                #pragma fragment frag
                #pragma target 5.0
			ENDCG
        }
	}
}
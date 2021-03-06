
//#ifdef cl_khr_fp64
//    #pragma OPENCL EXTENSION cl_khr_fp64 : enable
//#elif defined(cl_amd_fp64)
//    #pragma OPENCL EXTENSION cl_amd_fp64 : enable
//#else
//    #warning "Double precision floating point not supported by OpenCL implementation."
//#endif


// NE PAS MODIFIER
static unsigned color_mean (unsigned c1, unsigned c2)
{
  uchar4 c;

  c.x = ((unsigned)(((uchar4 *) &c1)->x) + (unsigned)(((uchar4 *) &c2)->x)) / 2;
  c.y = ((unsigned)(((uchar4 *) &c1)->y) + (unsigned)(((uchar4 *) &c2)->y)) / 2;
  c.z = ((unsigned)(((uchar4 *) &c1)->z) + (unsigned)(((uchar4 *) &c2)->z)) / 2;
  c.w = ((unsigned)(((uchar4 *) &c1)->w) + (unsigned)(((uchar4 *) &c2)->w)) / 2;

  return (unsigned) c;
}

// NE PAS MODIFIER
static int4 color_to_int4 (unsigned c)
{
  uchar4 ci = *(uchar4 *) &c;
  return convert_int4 (ci);
}

// NE PAS MODIFIER
static unsigned int4_to_color (int4 i)
{
  return (unsigned) convert_uchar4 (i);
}


////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// scrollup
////////////////////////////////////////////////////////////////////////////////

__kernel void scrollup (__global unsigned *in, __global unsigned *out)
{
  int y = get_global_id (1)+1;
  int x = get_global_id (0)+1;
  unsigned couleur;

  couleur = in [y * DIM + x];

  y = (y ? y - 1 : get_global_size (1) - 1);

  out [y * DIM + x] = couleur;
}


////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// sable
////////////////////////////////////////////////////////////////////////////////

__kernel void sable (__global unsigned *in, __global unsigned *out, __global int* diff)
{
  local int tmpReduction[TILEX][TILEY];//strat: calcul sum of the workgroup using memory protection, then reductiong all workgroups into global diff
  local int diffSum;
  int x = get_global_id (0)+1;
  int y = get_global_id (1)+1;
int xloc=get_local_id(0);
int yloc=get_local_id(1);
  int current = y*DIM+x;
diffSum=0;
//Avoid divergency, we gotta ensure that borders are 0, other wise this do not work
  out[current] = in[current]%4;
  out[current]+= in[current+1]/4; 
  out[current]+= in[current-1]/4;
  out[current]+= in[current+DIM]/4;
  out[current]+= in[current-DIM]/4;
//again, different versions (trying to avoid divergency) 
/*V1*/
/*
    atomic_add(diff,abs_diff(out[current],in[current]));
    

*/
/*V2 this do not work, need synchronization*/
/*
diff+= abs_diff(out[current],in[current]);
*/
/*V3 best and simpliest version*/
//*
if (out[current]-in[current]!=0)    
    atomic_inc(diff);
//*/
/*V4 less access to global memory*/
/*
atomic_add(&diffSum,abs_diff(out[current],in[current]));
barrier(CLK_LOCAL_MEM_FENCE);
if (xloc==0 && yloc==0)
    atomic_add(diff,diffSum);
*/

/*V5 v4 but getting rect of atomic, a lot slower*/
/*
tmpReduction[xloc][yloc]=abs_diff(out[current],in[current]);
int i;
int j;
barrier(CLK_LOCAL_MEM_FENCE);
if (xloc==0 && yloc==0){
    for (i=0; i<TILEX ; i++){
        for (j=0; j<TILEY ; j++){
            atomic_add(diff,tmpReduction[i][j]);
        }
    }
}
*/

}

// NE PAS MODIFIER
static float4 color_scatter (unsigned c)
{
  uchar4 ci;

  ci.s0123 = (*((uchar4 *) &c)).s3210;
  return convert_float4 (ci) / (float4) 255;
}

// NE PAS MODIFIER: ce noyau est appelé lorsqu'une mise à jour de la
// texture de l'image affichée est requise
__kernel void update_texture (__global unsigned *cur, __write_only image2d_t tex)
{
  int y = get_global_id (1);
  int x = get_global_id (0);
  int2 pos = (int2)(x, y);
  unsigned c = cur [y * DIM + x];
#ifdef KERNEL_sable
  unsigned r = 0, v = 0, b = 0;

  if (c == 1)
    v = 255;
  else if (c == 2)
    b = 255;
  else if (c == 3)
    r = 255;
  else if (c == 4)
    r = v = b = 255;
  else if (c > 4)
    r = v = b = (2 * c);

  c = (r << 24) + (v << 16) + (b << 8) + 0xFF;
#endif
  write_imagef (tex, pos, color_scatter (c));
}

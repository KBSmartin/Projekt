# Shared renderer for the enemy sprites (dot-source it). Shapes are distance
# fields, so parts of one group melt into each other without seams. One unit
# is one pixel: x to the right (the figure faces -x, towards the hero), y up
# from the ground, z towards the viewer. Light from the upper left, rim light
# from behind right, dark outline, at most 5 tones per ramp.
#
#   $s = New-Scene; $s.Ramp('fur', '#..', ...); $s.Group('fur', 2.0)
#   $s.Ell(...), $s.Cap(...), $s.Box(...), $s.Cut(...), $s.Mark(...)
#   $s.Push(...) / $s.Pop() move and turn everything added in between
#   $s.Yaw, $s.Pitch, $s.Zoom, $s.OffX, $s.OffY set the camera;
#   $s.Render(32) returns ARGB values
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('EnemyScene' -as [type])) {
  Add-Type -TypeDefinition @'
using System; using System.Collections.Generic;
public class EnemyScene {
  class Prim { public int type, mat; public bool cut; public double[] a, b, inv; public double r1, r2; public double[] bc; public double br; }
  class Grp { public double k; public int mat; public List<Prim> prims = new List<Prim>(); public List<Prim> cuts = new List<Prim>(); }
  class Mat { public string name; public int[] tones; public bool glow; public double noise, lift, crack, cell, grain, veinW, veinC; public int vein = -1; public bool fire; }
  class Mk { public double[] p; public string[] rows; public Dictionary<char,int> pal; public bool always; }
  List<Grp> groups = new List<Grp>(); List<Mat> mats = new List<Mat>(); List<Mk> marks = new List<Mk>();
  Grp cur; Stack<double[][]> stack = new Stack<double[][]>(); double[] T = new double[]{0,0,0}; double[] R = new double[]{1,0,0,0,1,0,0,0,1};
  public double Yaw = 20, Pitch = 10, OffX = 0, OffY = 0, EdgeDepth = 2.6, EdgeSame = 0, Zoom = 1, Contrast = 1;
  // Body warp for animations: everything above WY0 (fully above WY1) is shifted,
  // bent about the pivot (degrees, positive leans to -x), stretched and swayed;
  // what stands on the ground stays put. Set it before adding shapes.
  public double WBend = 0, WPivX = 0, WPivY = 0, WY0 = 0, WY1 = 12, WDx = 0, WDy = 0, WStretch = 1, WSway = 0, WSwayH = 24;
  double Wt(double y) { double t = Math.Max(0, Math.Min(1, (y-WY0)/(WY1-WY0))); return t*t*(3-2*t); }
  bool Warped { get { return WBend != 0 || WDx != 0 || WDy != 0 || WStretch != 1 || WSway != 0; } }
  double[] Warp(double[] v) {
    if (!Warped) return v;
    double w = Wt(v[1]), s = Math.Max(0, v[1])/WSwayH, x = v[0] + w*WDx + WSway*s*s, y = v[1]*WStretch + w*WDy, a = WBend*w*Math.PI/180;
    double px = x-WPivX, py = y-WPivY;
    return new double[]{ WPivX + px*Math.Cos(a) - py*Math.Sin(a), WPivY + px*Math.Sin(a) + py*Math.Cos(a), v[2] };
  }
  double[] RW(double x, double y, double z, double[] rot) { if (WBend == 0) return rot; double[] v = MV(R, new double[]{x,y,z}); return Mul(Rot(0,0,WBend*Wt(v[1]+T[1])), rot); }
  // EdgeSame: separate limit inside one group, for flat tops seen at a low angle.
  public bool Shadow = true, Flat = false, NoMarks = false;

  static int Hex(string h) { return unchecked((int)(0xff000000 | Convert.ToUInt32(h.TrimStart('#'), 16))); }
  public void Ramp(string name, params string[] tones) { AddMat(name, tones, false, 0, 0); }
  public void Glow(string name, params string[] tones) { AddMat(name, tones, true, 0, 0); }
  public void Rough(string name, double noise, double lift) { Mat m = mats[MatId(name)]; m.noise = noise; m.lift = lift; }
  // Turns a material (a glow, for example) into a dull one.
  public void Douse(string name, params string[] tones) { Mat m = mats[MatId(name)]; m.glow = false; m.fire = false; m.vein = -1; m.tones = new int[tones.Length]; for (int i = 0; i < tones.Length; i++) m.tones[i] = Hex(tones[i]); }
  // Stone: dark seams between cells of the given size. Bark: grooves running up.
  public void Crack(string name, double depth, double cell) { Mat m = mats[MatId(name)]; m.crack = depth; m.cell = cell; }
  // Glowing veins: along the cell seams the surface shows another material.
  public void Vein(string name, string other, double cell, double width) { Mat m = mats[MatId(name)]; m.vein = MatId(other); m.veinC = cell; m.veinW = width; }
  // Fire: bright core, darker towards the edge of the shape.
  public void Fire(string name, params string[] tones) { AddMat(name, tones, true, 0, 0); mats[mats.Count-1].fire = true; }
  public void Grain(string name, double depth) { mats[MatId(name)].grain = depth; }
  static double Hash(int x, int y, int z, int w) { uint h = (uint)(x*374761393 + y*668265263 + z*1274126177 + w*974711); h = (h ^ (h >> 13)) * 1274126177u; return ((h ^ (h >> 16)) & 0xffff) / 65535.0; }
  static double Seam(double x, double y, double z) {
    int ix = (int)Math.Floor(x), iy = (int)Math.Floor(y), iz = (int)Math.Floor(z); double f1 = 9, f2 = 9;
    for (int i = -1; i <= 1; i++) for (int j = -1; j <= 1; j++) for (int k = -1; k <= 1; k++) {
      int a = ix+i, b = iy+j, c = iz+k; double dx = a+Hash(a,b,c,1)-x, dy = b+Hash(a,b,c,2)-y, dz = c+Hash(a,b,c,3)-z, d = Math.Sqrt(dx*dx+dy*dy+dz*dz);
      if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) f2 = d;
    }
    return f2-f1;
  }
  void AddMat(string n, string[] t, bool g, double noise, double lift) { Mat m = new Mat(); m.name = n; m.glow = g; m.noise = noise; m.lift = lift; m.tones = new int[t.Length]; for (int i = 0; i < t.Length; i++) m.tones[i] = Hex(t[i]); mats.Add(m); }
  int MatId(string n) { for (int i = 0; i < mats.Count; i++) if (mats[i].name == n) return i; throw new Exception("unknown material " + n); }

  static double[] Mul(double[] A, double[] B) { double[] o = new double[9]; for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) o[i*3+j] = A[i*3]*B[j] + A[i*3+1]*B[3+j] + A[i*3+2]*B[6+j]; return o; }
  static double[] MV(double[] A, double[] v) { return new double[]{ A[0]*v[0]+A[1]*v[1]+A[2]*v[2], A[3]*v[0]+A[4]*v[1]+A[5]*v[2], A[6]*v[0]+A[7]*v[1]+A[8]*v[2] }; }
  static double[] MT(double[] A, double[] v) { return new double[]{ A[0]*v[0]+A[3]*v[1]+A[6]*v[2], A[1]*v[0]+A[4]*v[1]+A[7]*v[2], A[2]*v[0]+A[5]*v[1]+A[8]*v[2] }; }
  static double[] Rot(double rx, double ry, double rz) {
    double d = Math.PI/180, a = rx*d, b = ry*d, c = rz*d;
    double[] X = {1,0,0, 0,Math.Cos(a),-Math.Sin(a), 0,Math.Sin(a),Math.Cos(a)};
    double[] Y = {Math.Cos(b),0,Math.Sin(b), 0,1,0, -Math.Sin(b),0,Math.Cos(b)};
    double[] Z = {Math.Cos(c),-Math.Sin(c),0, Math.Sin(c),Math.Cos(c),0, 0,0,1};
    return Mul(Z, Mul(Y, X));
  }
  double[] W0(double x, double y, double z) { double[] v = MV(R, new double[]{x,y,z}); return new double[]{ v[0]+T[0], v[1]+T[1], v[2]+T[2] }; }
  double[] W(double x, double y, double z) { return Warp(W0(x,y,z)); }
  public void Push(double x, double y, double z, double rx, double ry, double rz) { stack.Push(new double[][]{T, R}); T = W0(x,y,z); R = Mul(R, Rot(rx,ry,rz)); }
  public void Pop() { double[][] o = stack.Pop(); T = o[0]; R = o[1]; }

  public void Group(string mat, double k) { cur = new Grp(); cur.k = k; cur.mat = MatId(mat); groups.Add(cur); }
  Prim Add(Prim p, string mat) { p.mat = mat == null || mat == "" ? cur.mat : MatId(mat); if (p.cut) cur.cuts.Add(p); else cur.prims.Add(p); return p; }
  Prim MkEll(double x, double y, double z, double rx, double ry, double rz, double ax, double ay, double az) {
    Prim p = new Prim(); p.type = 0; p.a = W(x,y,z); p.b = new double[]{rx,ry,rz}; p.inv = RW(x,y,z, Mul(R, Rot(ax,ay,az))); p.bc = p.a; p.br = Math.Max(rx, Math.Max(ry, rz)); return p;
  }
  public void Ell(double x, double y, double z, double rx, double ry, double rz, double ax, double ay, double az, string mat) { Add(MkEll(x,y,z,rx,ry,rz,ax,ay,az), mat); }
  public void Ball(double x, double y, double z, double r, string mat) { Add(MkEll(x,y,z,r,r,r,0,0,0), mat); }
  public void Cut(double x, double y, double z, double rx, double ry, double rz, double ax, double ay, double az, string mat) { Prim p = MkEll(x,y,z,rx,ry,rz,ax,ay,az); p.cut = true; Add(p, mat); }
  // Round cone from a (radius r1) to b (radius r2).
  public void Cap(double x1, double y1, double z1, double x2, double y2, double z2, double r1, double r2, string mat) {
    Prim p = new Prim(); p.type = 1; p.a = W(x1,y1,z1); p.b = W(x2,y2,z2); p.r1 = r1; p.r2 = r2;
    p.bc = new double[]{ (p.a[0]+p.b[0])/2, (p.a[1]+p.b[1])/2, (p.a[2]+p.b[2])/2 };
    double dx = p.a[0]-p.b[0], dy = p.a[1]-p.b[1], dz = p.a[2]-p.b[2]; p.br = Math.Sqrt(dx*dx+dy*dy+dz*dz)/2 + Math.Max(r1, r2); Add(p, mat);
  }
  public void Box(double x, double y, double z, double hx, double hy, double hz, double ax, double ay, double az, double round, string mat) {
    Prim p = new Prim(); p.type = 2; p.a = W(x,y,z); p.b = new double[]{hx-round,hy-round,hz-round}; p.r1 = round; p.inv = RW(x,y,z, Mul(R, Rot(ax,ay,az))); p.bc = p.a; p.br = Math.Sqrt(hx*hx+hy*hy+hz*hz); Add(p, mat);
  }
  // Crystal: faceted bipyramid with half axes a, h, c (h along its own y axis).
  public void Gem(double x, double y, double z, double a, double h, double c, double ax, double ay, double az, string mat) {
    Prim p = new Prim(); p.type = 3; p.a = W(x,y,z); p.b = new double[]{a,h,c}; p.inv = RW(x,y,z, Mul(R, Rot(ax,ay,az))); p.bc = p.a; p.br = Math.Max(a, Math.Max(h, c)); Add(p, mat);
  }
  // Chain of round cones through points (x,y,z triples), radius r1 to r2.
  public void Chain(double[] pts, double r1, double r2, string mat) {
    int n = pts.Length/3 - 1;
    for (int i = 0; i < n; i++) { double u = r1+(r2-r1)*i/n, v = r1+(r2-r1)*(i+1)/n; Cap(pts[i*3],pts[i*3+1],pts[i*3+2],pts[i*3+3],pts[i*3+4],pts[i*3+5],u,v,mat); }
  }
  // Pixel stamp at a point: rows split by '/', '.' is empty, colours as "R=#ff0000,w=#ffffff".
  public void Mark(double x, double y, double z, string rows, string colours, bool always) {
    Mk m = new Mk(); m.p = W(x,y,z); m.rows = rows.Split('/'); m.pal = new Dictionary<char,int>(); m.always = always;
    foreach (string c in colours.Split(',')) m.pal[c[0]] = Hex(c.Substring(2)); marks.Add(m);
  }

  static double D(Prim p, double x, double y, double z) {
    if (p.type == 1) {
      double bx = p.b[0]-p.a[0], by = p.b[1]-p.a[1], bz = p.b[2]-p.a[2], qx = x-p.a[0], qy = y-p.a[1], qz = z-p.a[2];
      double l2 = bx*bx+by*by+bz*bz + 1e-9, h = (qx*bx+qy*by+qz*bz)/l2; if (h < 0) h = 0; if (h > 1) h = 1;
      double ex = qx-bx*h, ey = qy-by*h, ez = qz-bz*h;
      return Math.Sqrt(ex*ex+ey*ey+ez*ez) - (p.r1+(p.r2-p.r1)*h);
    }
    double vx = x-p.a[0], vy = y-p.a[1], vz = z-p.a[2]; double[] m = p.inv;
    double lx = m[0]*vx+m[3]*vy+m[6]*vz, ly = m[1]*vx+m[4]*vy+m[7]*vz, lz = m[2]*vx+m[5]*vy+m[8]*vz;
    if (p.type == 0) {
      double ux = lx/p.b[0], uy = ly/p.b[1], uz = lz/p.b[2], k0 = Math.Sqrt(ux*ux+uy*uy+uz*uz);
      double wx = ux/p.b[0], wy = uy/p.b[1], wz = uz/p.b[2], k1 = Math.Sqrt(wx*wx+wy*wy+wz*wz);
      return k1 < 1e-9 ? -Math.Min(p.b[0], Math.Min(p.b[1], p.b[2])) : k0*(k0-1)/k1;
    }
    if (p.type == 3) return (Math.Abs(lx)/p.b[0] + Math.Abs(ly)/p.b[1] + Math.Abs(lz)/p.b[2] - 1) / Math.Sqrt(1/(p.b[0]*p.b[0]) + 1/(p.b[1]*p.b[1]) + 1/(p.b[2]*p.b[2]));
    double dx = Math.Abs(lx)-p.b[0], dy = Math.Abs(ly)-p.b[1], dz = Math.Abs(lz)-p.b[2];
    double ax = Math.Max(dx,0), ay = Math.Max(dy,0), az = Math.Max(dz,0);
    return Math.Sqrt(ax*ax+ay*ay+az*az) + Math.Min(Math.Max(dx, Math.Max(dy,dz)), 0) - p.r1;
  }
  double Eval(double x, double y, double z, out int mat, out int gid) {
    double best = 1e9; mat = 0; gid = -1;
    for (int g = 0; g < groups.Count; g++) {
      Grp G = groups[g]; double d = 1e9, near = 1e9; int gm = G.mat;
      foreach (Prim p in G.prims) {
        double cx = x-p.bc[0], cy = y-p.bc[1], cz = z-p.bc[2], lo = Math.Sqrt(cx*cx+cy*cy+cz*cz) - p.br;
        if (lo > best + G.k && lo > d + G.k) continue;
        double e = D(p,x,y,z);
        if (e < near) { near = e; gm = p.mat; }
        if (G.k > 0 && d < 1e8) { double h = Math.Max(G.k-Math.Abs(d-e),0)/G.k; d = Math.Min(d,e) - h*h*G.k/4; } else d = Math.Min(d,e);
      }
      foreach (Prim p in G.cuts) { double e = -D(p,x,y,z); if (e > d) { d = e; gm = p.mat; } }
      if (d < best) { best = d; mat = gm; gid = g; }
    }
    return best;
  }
  double[] V; double[] Dir;
  bool March(double[] o, double[] dir, double max, out double t, out int mat, out int gid) {
    t = 0; mat = 0; gid = 0;
    for (int i = 0; i < 140; i++) {
      double d = Eval(o[0]+dir[0]*t, o[1]+dir[1]*t, o[2]+dir[2]*t, out mat, out gid);
      if (d < 0.02) return true; t += d*0.85; if (t > max) return false;
    }
    return false;
  }
  static double[] N3(double x, double y, double z) { double l = Math.Sqrt(x*x+y*y+z*z); return new double[]{x/l,y/l,z/l}; }
  static double Dot(double[] a, double[] b) { return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]; }

  public int[] Render(int S) {
    V = Mul(Rot(Pitch,0,0), Rot(0,Yaw,0)); Dir = MT(V, new double[]{0,0,-1});
    double[] L = MT(V, N3(-0.6,0.75,0.55)), Rim = MT(V, N3(0.75,0.35,-0.55)), Vw = MT(V, new double[]{0,0,1});
    int[] px = new int[S*S]; double[] dep = new double[S*S]; int[] gids = new int[S*S], pm = new int[S*S]; bool[] solid = new bool[S*S];
    const int Q = 3; int M = mats.Count;
    for (int py = 0; py < S; py++) for (int pxx = 0; pxx < S; pxx++) {
      int hits = 0, shad = 0; double[] lum = new double[M]; int[] cnt = new int[M]; double dmin = 1e9; int g0 = -1;
      for (int s = 0; s < Q*Q; s++) {
        double sx = (pxx + ((s%Q)+0.5)/Q - S/2.0 - OffX)/Zoom, sy = ((S-2) - (py + ((s/Q)+0.5)/Q) - OffY)/Zoom;
        double[] o = MT(V, new double[]{sx, sy, 60}); double t; int mat, gid;
        if (!March(o, Dir, 130, out t, out mat, out gid)) {
          if (Shadow && Dir[1] < 0) {
            double tg = -o[1]/Dir[1]; double[] gp = { o[0]+Dir[0]*tg, 0.05, o[2]+Dir[2]*tg }; double t2; int m2, g2;
            if (March(gp, N3(L[0]*0.4,1,L[2]*0.4), 60, out t2, out m2, out g2)) shad++;
          }
          continue;
        }
        hits++; double[] h = { o[0]+Dir[0]*t, o[1]+Dir[1]*t, o[2]+Dir[2]*t }; const double E = 0.06; int a, b;
        double[] n = N3(Eval(h[0]+E,h[1],h[2],out a,out b)-Eval(h[0]-E,h[1],h[2],out a,out b), Eval(h[0],h[1]+E,h[2],out a,out b)-Eval(h[0],h[1]-E,h[2],out a,out b), Eval(h[0],h[1],h[2]+E,out a,out b)-Eval(h[0],h[1],h[2]-E,out a,out b)+1e-9);
        double diff = Math.Max(0, Dot(n,L)), fres = 1-Math.Max(0,Dot(n,Vw));
        double rim = Math.Pow(Math.Max(0,Dot(n,Rim)),1.5)*Math.Pow(fres,1.2);
        double ao = 0; for (int i = 1; i <= 3; i++) { double q = i*0.9; ao += Math.Max(0, q-Eval(h[0]+n[0]*q,h[1]+n[1]*q,h[2]+n[2]*q,out a,out b))/(1<<(i-1)); }
        double occ = Math.Max(0.25, 1-0.42*ao);
        double[] hw = h; if (Warped) { double[] m2 = Warp(h); h = new double[]{ 2*h[0]-m2[0], 2*h[1]-m2[1], h[2] }; }
        if (mats[mat].vein >= 0 && Seam(h[0]/mats[mat].veinC, h[1]/mats[mat].veinC, h[2]/mats[mat].veinC) < mats[mat].veinW) mat = mats[mat].vein;
        Mat mt = mats[mat]; double l = (0.16+0.66*diff)*occ + 0.5*rim + mt.lift;
        if (mt.noise > 0) l += mt.noise*Math.Sin(h[0]*2.3+h[2]*1.7)*Math.Sin(h[1]*2.1-h[2]*1.3);
        if (mt.crack > 0 && Seam(h[0]/mt.cell, h[1]/mt.cell, h[2]/mt.cell) < 0.16) l -= mt.crack;
        if (mt.grain > 0) l += mt.grain*Math.Sin((h[0]+h[2])*1.9 + 1.4*Math.Sin(h[1]*0.55));
        l = (l-0.42)*Contrast+0.42;
        if (mt.glow) l = 0.45+0.5*diff;
        if (mt.fire) l = 0.04+1.02*Math.Pow(Math.Max(0,Dot(n,Vw)),2.1);
        lum[mat] += l; cnt[mat]++; if (t < dmin) { dmin = t; g0 = gid; }
      }
      int I = py*S+pxx; dep[I] = 1e9;
      if (hits >= 4) {
        int bm = 0; for (int m = 1; m < M; m++) if (cnt[m]*(mats[m].glow?1.5:1) > cnt[bm]*(mats[bm].glow?1.5:1)) bm = m;
        double v = Math.Max(0, Math.Min(0.999, lum[bm]/cnt[bm])); int[] tn = mats[bm].tones;
        px[I] = tn[(int)(v*tn.Length)]; solid[I] = true; dep[I] = dmin; gids[I] = g0; pm[I] = bm;
      } else if (shad >= 5) px[I] = unchecked((int)0x6E08060A);
    }
    int[] res = (int[])px.Clone(); int[] dx = {1,-1,0,0}, dy = {0,0,1,-1};
    for (int y = 0; y < S; y++) for (int x = 0; x < S; x++) for (int k = 0; k < 4; k++) {
      int qx = x+dx[k], qy = y+dy[k]; if (qx < 0 || qy < 0 || qx >= S || qy >= S || !solid[qy*S+qx]) continue;
      int I = y*S+x, J = qy*S+qx;
      if (!solid[I]) { res[I] = Hex("#0c0a10"); break; }
      if (dep[I]-dep[J] > (EdgeSame > 0 && gids[I] == gids[J] ? EdgeSame : EdgeDepth) && !mats[pm[I]].glow) { res[I] = mats[pm[I]].tones[0]; break; }
    }
    foreach (Mk m in marks) { if (NoMarks) break;
      double[] q = MV(V, m.p); int cx = (int)Math.Floor(q[0]*Zoom+S/2.0+OffX), cy = (int)Math.Floor((S-2)-q[1]*Zoom-OffY);
      for (int r = 0; r < m.rows.Length; r++) for (int c = 0; c < m.rows[r].Length; c++) {
        char ch = m.rows[r][c]; if (ch == '.') continue; int x = cx+c-m.rows[r].Length/2, y = cy+r-m.rows.Length/2;
        if (x < 0 || y < 0 || x >= S || y >= S) continue; int I = y*S+x;
        if (!m.always && (!solid[I] || (60-dep[I]) > q[2]+2.5)) continue; res[I] = m.pal[ch];
      }
    }
    return res;
  }
}
'@
}
function New-Scene { [EnemyScene]::new() }
function New-Sprite($scene, [int]$size = 32) {
  $px = $scene.Render($size)
  $bmp = [Drawing.Bitmap]::new($size, $size)
  for ($i = 0; $i -lt $px.Length; $i++) { if ($px[$i] -ne 0) { $bmp.SetPixel($i % $size, [int][Math]::Floor($i / $size), [Drawing.Color]::FromArgb($px[$i])) } }
  $bmp
}


# Framing that fits the figure of $build into a size x size frame with a margin
# of one pixel (never enlarged beyond the zoom the pose asks for), centred;
# $Ground puts the lowest pixel on the bottom edge.
function Get-Fit([scriptblock]$build, [int]$size, [bool]$Ground = $true) {
  $s = New-Scene; & $build $s; $big = $s.Render(2 * $size); $S2 = 2 * $size
  $x0 = $S2; $x1 = -1; $y0 = $S2; $y1 = -1
  for ($i = 0; $i -lt $big.Length; $i++) { if ((($big[$i] -shr 24) -band 255) -eq 255) { $x = $i % $S2; $y = [int][Math]::Floor($i / $S2); if ($x -lt $x0) { $x0 = $x }; if ($x -gt $x1) { $x1 = $x }; if ($y -lt $y0) { $y0 = $y }; if ($y -gt $y1) { $y1 = $y } } }
  $f = [Math]::Min(1.0, [Math]::Min(($size - 2.6) / ($x1 - $x0 + 1), ($size - 1.6) / ($y1 - $y0 + 1)))
  @{ zoom = $s.Zoom * $f; ox = -((($x0 + $x1 + 1) / 2.0 - $size) - $s.OffX) * $f; oy = $(if ($Ground) { -0.6 - $f * ($S2 - 2 - $s.OffY - $y1) } else { $s.OffY * $f }) }
}
function New-FittedSprite([scriptblock]$build, [int]$size, [bool]$Ground = $true) {
  $fit = Get-Fit $build $size $Ground
  $t = New-Scene; & $build $t; $t.Zoom = $fit.zoom; $t.OffX = $fit.ox; $t.OffY = $fit.oy
  New-Sprite $t $size
}
# Opaque pixels on the left, right and top border (cut off if not 0).
function Get-Clipped($bmp) {
  $n = 0; $w = $bmp.Width
  for ($i = 0; $i -lt $w; $i++) { foreach ($q in @(0, $i), @(($w - 1), $i), @($i, 0)) { $c = $bmp.GetPixel($q[0], $q[1]); if ($c.A -eq 255 -and -not ($c.R -eq 12 -and $c.G -eq 10 -and $c.B -eq 16)) { $n++ } } }
  $n
}
# Pose sheet: per pose the sprite and silhouette at 1x, the silhouette and the
# form at 8x on grey, and the sprite at 4x in front of the region background.
function Save-PoseSheet([string]$file, [Collections.Specialized.OrderedDictionary]$sprites, [string]$background, [int]$first = 1) {
  $bg = [Drawing.Bitmap]::FromFile([IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\ui\assets\hintergrund\$background.png")))
  $sz = @($sprites.Values)[0].Width; $k = [int][Math]::Floor(256 / $sz); $fw = $sz * $k; $fh = $sz * 4 + 8; $top = 8 + $sz
  $cell = 268; $sh = [Drawing.Bitmap]::new($cell * $sprites.Count + 12, $top + 264 + 264 + $fh + 32)
  $g = [Drawing.Graphics]::FromImage($sh); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
  $g.Clear([Drawing.Color]::FromArgb(24, 24, 32))
  $grey = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(150, 150, 158)); $font = [Drawing.Font]::new('Consolas', 11)
  $i = 0
  foreach ($name in $sprites.Keys) {
    $img = $sprites[$name]; $sil = [Drawing.Bitmap]::new($sz, $sz); $x0 = 12 + $i * $cell
    for ($y = 0; $y -lt $sz; $y++) { for ($x = 0; $x -lt $sz; $x++) { if ($img.GetPixel($x, $y).A -gt 200) { $sil.SetPixel($x, $y, [Drawing.Color]::FromArgb(12, 10, 16)) } } }
    $g.FillRectangle($grey, $x0, 4, 2 * $sz + 8, $sz); $g.DrawImage($img, $x0, 4, $sz, $sz); $g.DrawImage($sil, $x0 + $sz + 8, 4, $sz, $sz)
    $g.FillRectangle($grey, $x0, $top, 256, 256); $g.DrawImage($sil, $x0, $top, $fw, $fw)
    $g.FillRectangle($grey, $x0, $top + 264, 256, 256); $g.DrawImage($img, $x0, $top + 264, $fw, $fw)
    $g.DrawImage($bg, [Drawing.Rectangle]::new($x0, $top + 528, 256, $fh), [Drawing.Rectangle]::new(100, 148 - [int]($fh / 4), 64, [int]($fh / 4)), 'Pixel')
    $g.DrawImage($img, $x0 + 128 - 2 * $sz, $top + 532, 4 * $sz, 4 * $sz)
    $g.DrawString("$($first + $i) $name", $font, [Drawing.Brushes]::White, $x0, $top + 532 + $fh)
    $sil.Dispose(); $i++
  }
  $g.Dispose(); $bg.Dispose(); $sh.Save($file); $sh.Dispose()
}

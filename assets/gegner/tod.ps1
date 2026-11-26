# Death effects on a finished frame (dot-source; used by anim.ps1 and rat.ps1).
# The outline is taken off first and drawn again around what is left, so the
# pieces look like the rest of the sprite. t runs from 0 to 1.
#   Chunks  breaks into pieces of about `cell` pixels that fall and pile up
#   Ash     pixels come loose from the top down (or all over), glow and blow away
if (-not ('EnemyFx' -as [type])) {
  Add-Type -TypeDefinition @'
using System; using System.Collections.Generic;
public static class EnemyFx {
  const int Line = unchecked((int)0xff0c0a10);
  static double H(int x, int y, int w) { uint h = (uint)(x*374761393 + y*668265263 + w*974711); h = (h ^ (h >> 13)) * 1274126177u; return ((h ^ (h >> 16)) & 0xffff) / 65535.0; }
  static bool Solid(int c) { return ((c >> 24) & 255) == 255 && c != Line; }
  static void Outline(int[] o, int S) {
    int[] src = (int[])o.Clone(); int[] dx = {1,-1,0,0}, dy = {0,0,1,-1};
    for (int y = 0; y < S; y++) for (int x = 0; x < S; x++) { if (Solid(src[y*S+x])) continue;
      for (int k = 0; k < 4; k++) { int a = x+dx[k], b = y+dy[k]; if (a >= 0 && b >= 0 && a < S && b < S && Solid(src[b*S+a])) { o[y*S+x] = Line; break; } } }
  }
  static void Box(int[] px, int S, out int x0, out int x1, out int y0, out int y1) {
    x0 = S; x1 = -1; y0 = S; y1 = -1;
    for (int y = 0; y < S; y++) for (int x = 0; x < S; x++) if (Solid(px[y*S+x])) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
  }
  class Piece { public List<int> x = new List<int>(), y = new List<int>(), c = new List<int>(); public double cx, cy; public int id; }
  public static int[] Chunks(int[] px, int S, double t, double cell, int seed, double spread, double pile) {
    if (t <= 0) return px;
    int x0, x1, y0, y1; Box(px, S, out x0, out x1, out y0, out y1); int[] res = new int[S*S]; if (x1 < 0) return res;
    var map = new Dictionary<int, Piece>();
    for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) { if (!Solid(px[y*S+x])) continue;
      int gx = (int)(x/cell), gy = (int)(y/cell), best = 0; double bd = 1e9;
      for (int i = -1; i <= 1; i++) for (int j = -1; j <= 1; j++) { int a = gx+i, b = gy+j; double ux = (a+0.15+0.7*H(a,b,seed))*cell-x, uy = (b+0.15+0.7*H(a,b,seed+7))*cell-y, d = ux*ux+uy*uy; if (d < bd) { bd = d; best = (b+50)*1000+a+50; } }
      Piece p; if (!map.TryGetValue(best, out p)) { p = new Piece(); p.id = best; map[best] = p; }
      p.x.Add(x); p.y.Add(y); p.c.Add(px[y*S+x]); }
    var list = new List<Piece>(map.Values);
    foreach (Piece p in list) { foreach (int v in p.x) p.cx += v; foreach (int v in p.y) p.cy += v; p.cx /= p.x.Count; p.cy /= p.x.Count; }
    list.Sort((a, b) => a.cy != b.cy ? b.cy.CompareTo(a.cy) : a.id.CompareTo(b.id));
    double mid = (x0+x1)/2.0, high = Math.Max(1, y1-y0); double[] top = new double[S]; for (int i = 0; i < S; i++) top[i] = y1;
    foreach (Piece p in list) {
      double r = H(p.id, 3, seed), q = H(p.id, 5, seed), fx = (p.cx-mid)*spread*0.5 + (q-0.5)*spread*6; int lo = S, hi = -1; foreach (int v in p.x) { lo = Math.Min(lo, v); hi = Math.Max(hi, v); }
      fx = Math.Max(2-lo, Math.Min(S-3-hi, fx)); int mx = (int)Math.Round(fx);
      // Landing: down until the piece has sunk into the pile under its middle.
      double fall = 0; int floor = S; var low = new Dictionary<int,int>(); var upp = new Dictionary<int,int>();
      for (int i = 0; i < p.x.Count; i++) { int k = p.x[i]+mx, v; if (!low.TryGetValue(k, out v) || p.y[i] > v) low[k] = p.y[i]; if (!upp.TryGetValue(k, out v) || p.y[i] < v) upp[k] = p.y[i]; }
      foreach (var e in low) { fall += (top[e.Key]-e.Value)/(double)low.Count; floor = Math.Min(floor, y1-e.Value); }
      fall = Math.Max(0, Math.Min(floor, fall));
      foreach (var e in low) { double h = low[e.Key]-upp[e.Key]+1; top[e.Key] = Math.Min(top[e.Key], e.Value+fall-h*pile); }
      double d = 0.22*r + 0.12*(y1-p.cy)/high, len = 0.22+0.44*Math.Sqrt(fall/high), u = Math.Max(0, Math.Min(1, (t-d)/len));
      int ox = (int)Math.Round(mx*u), oy = (int)Math.Round(fall*u*u);
      for (int i = 0; i < p.x.Count; i++) { int X = p.x[i]+ox, Y = p.y[i]+oy; if (X >= 0 && X < S && Y >= 0 && Y < S) res[Y*S+X] = p.c[i]; }
    }
    Outline(res, S); return res;
  }
  // keep: share of the height at the bottom that stays; down: 1 = top first, 0 = all over.
  public static int[] Ash(int[] px, int S, double t, int seed, int[] ember, double rise, double wind, double keep, double down) {
    if (t <= 0) return px;
    int x0, x1, y0, y1; Box(px, S, out x0, out x1, out y0, out y1); int[] res = new int[S*S]; if (x1 < 0) return res;
    double high = Math.Max(1, y1-y0); int[] fly = new int[S*S];
    for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) { int c = px[y*S+x]; if (!Solid(c)) continue;
      double f = (y-y0)/high, r = 0.6*H(x/2, y/2, seed)+0.4*H(x, y, seed+1), rel = 0.62*(down*f + (1-down)*r) + 0.14*r;
      if (f > 1-keep) { res[y*S+x] = c; continue; }
      double u = (t-rel)/0.24;
      if (u <= -0.35) { res[y*S+x] = c; continue; }
      if (u <= 0) { res[y*S+x] = ember[ember.Length-1]; continue; }
      if (u >= 1 || H(x, y, seed+9) > 0.62-0.4*u) continue;
      int X = x+(int)Math.Round(wind*u*(0.5+H(x,y,seed+3))), Y = y-(int)Math.Round(rise*u*(0.4+H(x,y,seed+4)));
      if (X >= 1 && Y >= 1 && X < S-1 && Y < S-1) fly[Y*S+X] = ember[Math.Max(0, ember.Length-1-(int)(u*ember.Length))];
    }
    Outline(res, S);
    for (int i = 0; i < S*S; i++) if (fly[i] != 0 && !Solid(res[i])) res[i] = fly[i];
    return res;
  }
}
'@
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:budget_analyzer/domain/models/project.dart';
import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/domain/models/insumo.dart';
import 'package:budget_analyzer/domain/models/capitulo.dart';

class SupabaseHelper {
  static final SupabaseHelper instance = SupabaseHelper._init();
  final SupabaseClient _supabase = Supabase.instance.client;

  SupabaseHelper._init();

  // --- Operaciones para Proyectos ---

  Future<int> insertProject(Project project) async {
    final List<Map<String, dynamic>> result = await _supabase
        .from('projects')
        .select()
        .eq('name', project.name);
    
    if (result.isNotEmpty) {
      return result.first['id'] as int;
    }

    final insertResult = await _supabase
        .from('projects')
        .insert(project.toMap())
        .select();
        
    return insertResult.first['id'] as int;
  }

  Future<List<Project>> getAllProjects() async {
    final response = await _supabase.from('projects').select();
    return response.map((json) => Project.fromMap(json)).toList();
  }

  // --- Operaciones para Capítulos ---

  Future<List<Capitulo>> insertCapitulos(List<Capitulo> capitulos) async {
    final capitulosMaps = capitulos.map((c) => c.toMap()).toList();
    final response = await _supabase
        .from('capitulos')
        .upsert(capitulosMaps, onConflict: 'id') // Though they shouldn't have IDs yet
        .select();

    List<Capitulo> savedCapitulos = response.map((json) => Capitulo.fromMap(json)).toList();
    return savedCapitulos;
  }

  Future<int> insertCapitulo(Capitulo capitulo) async {
    final response = await _supabase
        .from('capitulos')
        .upsert(capitulo.toMap())
        .select();
    return response.first['id'] as int;
  }

  Future<List<Capitulo>> getCapitulosByProject(int projectId) async {
    final response = await _supabase
        .from('capitulos')
        .select()
        .eq('projectId', projectId)
        .order('numero', ascending: true);
    return response.map((json) => Capitulo.fromMap(json)).toList();
  }

  Future<List<Capitulo>> getAllCapitulos() async {
    final response = await _supabase
        .from('capitulos')
        .select()
        .order('numero', ascending: true);
    return response.map((json) => Capitulo.fromMap(json)).toList();
  }

  // --- Operaciones para APUs / Activities ---

  Future<List<Apu>> insertApus(List<Apu> apus) async {
    List<Apu> savedApus = [];
    
    // We process sequentially since we need the auto-generated ID for insumos
    for (var apu in apus) {
      // 1. Insert activity
      final activityMap = apu.toMap();
      final activityResponse = await _supabase
          .from('activities')
          .insert(activityMap)
          .select();
          
      final activityId = activityResponse.first['id'] as int;
      
      // 2. Prepare insumos
      final insumoMaps = apu.insumos.map((insumo) {
        final map = insumo.toMap();
        map['activityId'] = activityId;
        map.remove('id');
        return map;
      }).toList();
      
      // 3. Insert insumos if any
      List<Insumo> savedInsumos = [];
      if (insumoMaps.isNotEmpty) {
        final insumoResponse = await _supabase
            .from('insumos')
            .insert(insumoMaps)
            .select();
            
        savedInsumos = insumoResponse.map((json) => Insumo.fromMap(json)).toList();
      }
      
      // 4. Combine
      savedApus.add(Apu.fromMap(activityResponse.first, insumos: savedInsumos));
    }
    
    return savedApus;
  }

  Future<int> insertApu(Apu apu) async {
    final activityResponse = await _supabase
        .from('activities')
        .insert(apu.toMap())
        .select();
        
    final activityId = activityResponse.first['id'] as int;
    
    final insumoMaps = apu.insumos.map((insumo) {
      final map = insumo.toMap();
      map['activityId'] = activityId;
      map.remove('id');
      return map;
    }).toList();
    
    if (insumoMaps.isNotEmpty) {
      await _supabase.from('insumos').insert(insumoMaps);
    }
    
    return activityId;
  }

  Future<List<Apu>> getAllApus() async {
    final activityResponse = await _supabase.from('activities').select();
    final insumoResponse = await _supabase.from('insumos').select();

    List<Apu> result = [];
    for (var activityMap in activityResponse) {
      final activityId = activityMap['id'] as int;
      
      final activityInsumos = insumoResponse
          .where((i) => i['activityId'] == activityId)
          .map((map) => Insumo.fromMap(map))
          .toList();

      result.add(Apu.fromMap(activityMap, insumos: activityInsumos));
    }
    return result;
  }

  Future<List<Apu>> getApusByProject(int projectId) async {
    // We use a foreign table inner join in Supabase
    final response = await _supabase
        .from('activities')
        .select('*, capitulos!inner(*)')
        .eq('capitulos.projectId', projectId);

    final insumoResponse = await _supabase.from('insumos').select();

    List<Apu> result = [];
    for (var row in response) {
      // Need to clean the map by removing the joined object before passing to Apu.fromMap
      final activityMap = Map<String, dynamic>.from(row);
      activityMap.remove('capitulos');
      
      final activityId = activityMap['id'] as int;
      
      final activityInsumos = insumoResponse
          .where((i) => i['activityId'] == activityId)
          .map((map) => Insumo.fromMap(map))
          .toList();

      result.add(Apu.fromMap(activityMap, insumos: activityInsumos));
    }
    return result;
  }

  Future<List<Insumo>> getAllInsumos() async {
    final response = await _supabase.from('insumos').select();
    return response.map((json) => Insumo.fromMap(json)).toList();
  }

  // --- Operaciones de Cortes (EVM) ---

  Future<int> insertCutRecord(
    Map<String, dynamic> cutMap,
    List<Map<String, dynamic>> purchases,
  ) async {
    final cutResponse = await _supabase
        .from('cut_records')
        .insert(cutMap)
        .select();
        
    final cutRecordId = cutResponse.first['id'] as int;
    
    if (purchases.isNotEmpty) {
      final purchasesWithId = purchases.map((p) {
        final pMap = Map<String, dynamic>.from(p);
        pMap['cutRecordId'] = cutRecordId;
        return pMap;
      }).toList();
      
      await _supabase.from('cut_insumo_purchases').insert(purchasesWithId);
    }
    
    return cutRecordId;
  }

  Future<List<Map<String, dynamic>>> getCutRecordsForActivity(int activityId) async {
    return await _supabase
        .from('cut_records')
        .select()
        .eq('activityId', activityId)
        .order('cutNumber', ascending: true);
  }

  Future<List<Map<String, dynamic>>> getPurchasesForCut(int cutRecordId) async {
    return await _supabase
        .from('cut_insumo_purchases')
        .select()
        .eq('cutRecordId', cutRecordId);
  }

  // --- Operaciones de Gastos (Open Cuts) ---

  Future<Map<String, dynamic>?> getOpenCutRecordForActivity(int activityId) async {
    final response = await _supabase
        .from('cut_records')
        .select()
        .eq('activityId', activityId)
        .eq('isClosed', 0)
        .order('cutNumber', ascending: false)
        .limit(1);
        
    if (response.isNotEmpty) return response.first;
    return null;
  }

  Future<int> insertPurchaseIntoCut(int cutRecordId, Map<String, dynamic> purchase) async {
    final pMap = Map<String, dynamic>.from(purchase);
    pMap['cutRecordId'] = cutRecordId;
    
    final response = await _supabase
        .from('cut_insumo_purchases')
        .insert(pMap)
        .select();
        
    return response.first['id'] as int;
  }

  Future<void> updateCutRecord(int id, Map<String, dynamic> cutMap) async {
    await _supabase
        .from('cut_records')
        .update(cutMap)
        .eq('id', id);
  }
}
